"""
spacewar_env_wrap.py
SpaceWar 2062 physics — WRAP edges (torus world).

Differences from spacewar_env.py (bounce):
  - Ships and bullets wrap at world edges instead of reflecting.
  - Opponent position and bullet positions in the observation are expressed
    as the NEAREST TORUS DELTA from the agent, not absolute world coords.
    This is the critical change: without it the agent sees the opponent
    "teleport" across the screen every time they cross an edge, making
    the relative-position signal completely uninformative.
  - Approach-reward distance uses torus (shortest-path) distance.
  - _prev_dist also uses torus distance.

NeuralAIController.swift must pass the same torus-relative values when
building the observation vector for this model (see comments there).
"""

from __future__ import annotations

import math
import copy
import random
import numpy as np
import gymnasium as gym
from gymnasium import spaces


# ---------------------------------------------------------------------------
# Snapshot pool (identical to bounce version)
# ---------------------------------------------------------------------------

class SnapshotPool:
    def __init__(self, pool_size: int = 5):
        self.pool_size = pool_size
        self.snapshots: list = []

    def add(self, policy) -> None:
        snap = copy.deepcopy(policy)
        snap.set_training_mode(False)
        self.snapshots.append(snap)
        if len(self.snapshots) > self.pool_size:
            self.snapshots.pop(0)

    def sample_fn(self):
        if not self.snapshots:
            return None
        policy = random.choice(self.snapshots)
        import torch

        def act(obs_np: np.ndarray) -> np.ndarray:
            with torch.no_grad():
                t = torch.FloatTensor(obs_np).unsqueeze(0)
                actions, _, _ = policy(t, deterministic=False)
            return actions.squeeze(0).cpu().numpy()

        return act


# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

class SpaceWarWrapEnv(gym.Env):
    """
    Observation (46 float32) — same layout as bounce env EXCEPT:
      [6-7]   nearest-torus delta to opponent / (W, H)
              i.e. (opp_x - my_x + wrap_offset) / W, same for y
      [14-45] nearest-torus delta to each bullet / (W, H)
              i.e. the dx/dy are the shortest-path offset on the torus

    My own absolute position [0-1] is still sent as-is because the agent
    needs it to reason about sun proximity (sun is at a fixed world point).

    Action  MultiDiscrete([3, 2, 2]): identical to bounce version.
    """

    W  = 3000.0
    H  = 3000.0
    SUN_X = 1500.0
    SUN_Y = 1500.0
    SUN_R      = 28.0
    SUN_KILL_R = 38.0
    G_SHIP     = 18000.0 * 8.0
    G_BULLET   = 18000.0 * 5.0
    THRUST     = 250.0
    MAX_SPEED  = 400.0
    ROT_SPEED  = math.pi * 2
    BULLET_SPEED = 480.0
    BULLET_LIFE  = 3.0
    HIT_R        = 15.0

    SPAWN_X_BANDS = [(300, 900), (2100, 2700)]
    SPAWN_Y_RANGE = (300, 2700)

    MAX_ENEMY_BULLETS  = 8
    FIRE_COOLDOWN_FRAMES = 3
    DT        = 1.0 / 30.0
    MAX_STEPS = 1800

    OBS_SIZE = 14 + MAX_ENEMY_BULLETS * 4   # = 46

    _MAX_DIST = math.hypot(3000 / 2, 3000 / 2)   # max torus distance = half-diagonal

    # ------------------------------------------------------------------ #

    def __init__(self, snapshot_pool: SnapshotPool | None = None):
        super().__init__()
        self.snapshot_pool = snapshot_pool
        self._opponent_fn  = None

        self.observation_space = spaces.Box(
            low=-3.0, high=3.0, shape=(self.OBS_SIZE,), dtype=np.float32)
        self.action_space = spaces.MultiDiscrete([3, 2, 2])

        self.pos   = np.zeros((2, 2))
        self.vel   = np.zeros((2, 2))
        self.angle = np.zeros(2)
        self.bullets: list[dict] = []
        self.fire_cd = [0, 0]
        self.steps   = 0
        self._prev_dist: float = 0.0

    # ------------------------------------------------------------------ #
    # Torus helpers                                                         #
    # ------------------------------------------------------------------ #

    def _torus_delta(self, ax: float, ay: float,
                     bx: float, by: float) -> tuple[float, float]:
        """
        Shortest-path delta from point a to point b on the torus.
        Returns (dx, dy) such that |dx| <= W/2 and |dy| <= H/2.
        """
        W, H = self.W, self.H
        dx = bx - ax
        dy = by - ay
        # Wrap each component independently to the nearest copy
        if   dx >  W / 2: dx -= W
        elif dx < -W / 2: dx += W
        if   dy >  H / 2: dy -= H
        elif dy < -H / 2: dy += H
        return dx, dy

    def _torus_dist(self, i: int, j: int) -> float:
        dx, dy = self._torus_delta(
            self.pos[i, 0], self.pos[i, 1],
            self.pos[j, 0], self.pos[j, 1])
        return math.hypot(dx, dy)

    # ------------------------------------------------------------------ #
    # Reset                                                                 #
    # ------------------------------------------------------------------ #

    def reset(self, seed=None, options=None):
        super().reset(seed=seed)
        rng = self.np_random

        def rand_spawn(band_idx: int) -> list:
            xlo, xhi = self.SPAWN_X_BANDS[band_idx]
            ylo, yhi = self.SPAWN_Y_RANGE
            return [float(rng.integers(xlo, xhi)),
                    float(rng.integers(ylo, yhi))]

        self.pos   = np.array([rand_spawn(0), rand_spawn(1)], dtype=np.float64)
        self.vel   = np.zeros((2, 2), dtype=np.float64)
        base_angles = [-math.pi / 2, math.pi / 2]
        self.angle = np.array([
            base_angles[i] + rng.uniform(-math.pi/6, math.pi/6)
            for i in range(2)
        ], dtype=np.float64)
        self.bullets = []
        self.fire_cd = [0, 0]
        self.steps   = 0
        self._prev_dist = self._torus_dist(0, 1)

        if self.snapshot_pool is not None:
            fn = self.snapshot_pool.sample_fn()
            if fn is not None:
                self._opponent_fn = fn

        return self._obs(0), {}

    # ------------------------------------------------------------------ #
    # Observation                                                          #
    # ------------------------------------------------------------------ #

    def _obs(self, me: int) -> np.ndarray:
        opp = 1 - me
        W, H = self.W, self.H
        ms   = self.MAX_SPEED
        bs   = self.BULLET_SPEED

        o: list[float] = []

        # [0-1] My absolute position (agent needs this for sun-proximity reasoning)
        o += [self.pos[me, 0] / W,  self.pos[me, 1] / H]
        # [2-3] My velocity
        o += [self.vel[me, 0] / ms, self.vel[me, 1] / ms]
        # [4-5] My heading
        o += [math.sin(self.angle[me]), math.cos(self.angle[me])]

        # [6-7] Opponent: NEAREST TORUS DELTA (not absolute position)
        #       This stays bounded to [-W/2, W/2] x [-H/2, H/2] so the agent
        #       never sees the opponent "jump" when they cross an edge.
        odx, ody = self._torus_delta(
            self.pos[me, 0], self.pos[me, 1],
            self.pos[opp, 0], self.pos[opp, 1])
        o += [odx / W, ody / H]

        # [8-9] Opponent velocity
        o += [self.vel[opp, 0] / ms, self.vel[opp, 1] / ms]
        # [10-11] Opponent heading
        o += [math.sin(self.angle[opp]), math.cos(self.angle[opp])]

        # [12-13] Direction to sun (relative to me, absolute coords fine —
        #         sun is fixed at world centre, no wrap ambiguity)
        o += [(self.SUN_X - self.pos[me, 0]) / W,
              (self.SUN_Y - self.pos[me, 1]) / H]

        # [14-45] Closest 8 enemy bullets — NEAREST TORUS DELTA for position
        mx, my = self.pos[me]
        def torus_d2(b: dict) -> float:
            dx, dy = self._torus_delta(mx, my, b['px'], b['py'])
            return dx * dx + dy * dy

        enemy_b = sorted(
            [b for b in self.bullets if b['owner'] != me],
            key=torus_d2)

        for i in range(self.MAX_ENEMY_BULLETS):
            if i < len(enemy_b):
                b = enemy_b[i]
                bdx, bdy = self._torus_delta(mx, my, b['px'], b['py'])
                o += [bdx / W,
                      bdy / H,
                      b['vx'] / bs,
                      b['vy'] / bs]
            else:
                o += [0.0, 0.0, 0.0, 0.0]

        return np.array(o, dtype=np.float32)

    # ------------------------------------------------------------------ #
    # Action application (identical to bounce)                             #
    # ------------------------------------------------------------------ #

    def _apply_action(self, i: int, action) -> None:
        rot = int(action[0])
        thr = int(action[1])
        fir = int(action[2])
        dt  = self.DT

        if rot == 0:
            self.angle[i] -= self.ROT_SPEED * dt
        elif rot == 2:
            self.angle[i] += self.ROT_SPEED * dt

        if thr:
            self.vel[i, 0] += -math.sin(self.angle[i]) * self.THRUST * dt
            self.vel[i, 1] +=  math.cos(self.angle[i]) * self.THRUST * dt

        if fir and self.fire_cd[i] == 0:
            a = self.angle[i]
            self.bullets.append({
                'px': self.pos[i, 0],
                'py': self.pos[i, 1],
                'vx': -math.sin(a) * self.BULLET_SPEED,
                'vy':  math.cos(a) * self.BULLET_SPEED,
                'owner': i,
                'life':  self.BULLET_LIFE,
            })
            self.fire_cd[i] = self.FIRE_COOLDOWN_FRAMES

        if self.fire_cd[i] > 0:
            self.fire_cd[i] -= 1

    # ------------------------------------------------------------------ #
    # Physics — WRAP edges                                                 #
    # ------------------------------------------------------------------ #

    def _step_physics(self) -> None:
        dt = self.DT
        W, H = self.W, self.H
        sx, sy = self.SUN_X, self.SUN_Y

        # Ships
        for i in range(2):
            dx = sx - self.pos[i, 0]
            dy = sy - self.pos[i, 1]
            r2 = dx * dx + dy * dy + 100.0
            r  = math.sqrt(r2)
            a  = self.G_SHIP / r2
            self.vel[i, 0] += (dx / r) * a * dt
            self.vel[i, 1] += (dy / r) * a * dt
            spd = math.hypot(self.vel[i, 0], self.vel[i, 1])
            if spd > self.MAX_SPEED:
                k = self.MAX_SPEED / spd
                self.vel[i, 0] *= k
                self.vel[i, 1] *= k
            self.pos[i, 0] = (self.pos[i, 0] + self.vel[i, 0] * dt) % W
            self.pos[i, 1] = (self.pos[i, 1] + self.vel[i, 1] * dt) % H

        # Bullets
        alive = []
        for b in self.bullets:
            dx = sx - b['px']
            dy = sy - b['py']
            r2 = dx * dx + dy * dy + 100.0
            r  = math.sqrt(r2)
            a  = self.G_BULLET / r2
            b['vx'] += (dx / r) * a * dt
            b['vy'] += (dy / r) * a * dt
            b['px'] = (b['px'] + b['vx'] * dt) % W
            b['py'] = (b['py'] + b['vy'] * dt) % H
            # Sun collision (still applies after wrap)
            bdx = b['px'] - sx; bdy = b['py'] - sy
            if bdx * bdx + bdy * bdy <= self.SUN_R ** 2:
                continue
            b['life'] -= dt
            if b['life'] > 0:
                alive.append(b)
        self.bullets = alive

    # ------------------------------------------------------------------ #
    # Hit detection — torus-aware                                          #
    # ------------------------------------------------------------------ #

    def _check_hits(self) -> dict:
        r2   = self.HIT_R ** 2
        sr2  = self.SUN_KILL_R ** 2
        sx, sy = self.SUN_X, self.SUN_Y
        result = {'agent_shot': False, 'opp_shot': False,
                  'agent_sun':  False, 'opp_sun':  False}

        keep = []
        for b in self.bullets:
            target = 1 - b['owner']
            # Use torus delta so bullets that wrap around still register hits
            dx, dy = self._torus_delta(
                self.pos[target, 0], self.pos[target, 1],
                b['px'], b['py'])
            if dx * dx + dy * dy <= r2:
                if target == 0: result['agent_shot'] = True
                else:           result['opp_shot']   = True
            else:
                keep.append(b)
        self.bullets = keep

        for i in range(2):
            dx = self.pos[i, 0] - sx
            dy = self.pos[i, 1] - sy
            if dx * dx + dy * dy <= sr2:
                if i == 0: result['agent_sun'] = True
                else:      result['opp_sun']   = True

        return result

    # ------------------------------------------------------------------ #
    # Step                                                                 #
    # ------------------------------------------------------------------ #

    def step(self, action):
        self._apply_action(0, action)

        if self._opponent_fn is not None:
            opp_obs = self._obs(1)
            try:
                opp_act = self._opponent_fn(opp_obs)
            except Exception:
                opp_act = self.action_space.sample()
        else:
            opp_act = self.action_space.sample()
        self._apply_action(1, opp_act)

        self._step_physics()
        self.steps += 1

        hits = self._check_hits()

        reward = 0.0

        if hits['opp_shot'] or hits['opp_sun']:
            reward += 1.0
        if hits['agent_shot'] or hits['agent_sun']:
            reward -= 1.0
        terminated = hits['opp_shot'] or hits['opp_sun'] \
                  or hits['agent_shot'] or hits['agent_sun']

        # Approach shaping — TORUS distance so closing by wrapping is rewarded
        curr_dist = self._torus_dist(0, 1)
        approach  = (self._prev_dist - curr_dist) / self._MAX_DIST
        reward   += approach * 0.4
        self._prev_dist = curr_dist

        if 150 < curr_dist < 600:
            reward += 0.0008

        reward -= 0.002

        truncated = self.steps >= self.MAX_STEPS
        return self._obs(0), float(reward), terminated, truncated, {}
