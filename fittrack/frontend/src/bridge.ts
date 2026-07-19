export type SetState = "pending" | "active" | "completed";

export interface WorkoutSet {
  id: string;
  number: number;
  weightKg: number;
  reps: number;
  state: SetState;
}

export interface ExerciseSummary {
  id: string;
  name: string;
  image: string;
  meta: string;
  notes?: string;
  sets: WorkoutSet[];
}

export interface WorkoutSnapshot {
  title: string;
  progress: string;
  elapsed: string;
  totalVolume: string;
  completedSets: number;
  restSeconds: number;
  restRunning: boolean;
  current: ExerciseSummary;
  next: ExerciseSummary | null;
}

export interface FitTrackBridge {
  getSnapshot(): Promise<WorkoutSnapshot>;
  updateSet(setId: string, weightKg: number, reps: number): Promise<void>;
  completeSet(setId: string): Promise<void>;
  addSet(): Promise<void>;
  openNextExercise(): Promise<void>;
  pauseRest(): Promise<void>;
  skipRest(): Promise<void>;
}

const mockSnapshot: WorkoutSnapshot = {
  title: "记录训练",
  progress: "Push · 第1/5个动作",
  elapsed: "00:42:15",
  totalVolume: "1,824 kg",
  completedSets: 7,
  restSeconds: 88,
  restRunning: true,
  current: {
    id: "incline-dumbbell-press",
    name: "哑铃上斜卧推",
    image: "./images/incline-dumbbell-bench-press.jpg",
    meta: "胸部 · 4组 · 8–12次",
    notes: "肩胛收紧，动作底部保持控制。",
    sets: [
      { id: "set-1", number: 1, weightKg: 30, reps: 12, state: "completed" },
      { id: "set-2", number: 2, weightKg: 32.5, reps: 10, state: "active" },
      { id: "set-3", number: 3, weightKg: 32.5, reps: 10, state: "pending" },
      { id: "set-4", number: 4, weightKg: 32.5, reps: 10, state: "pending" },
    ],
  },
  next: {
    id: "barbell-bench-press",
    name: "杠铃卧推",
    image: "./images/barbell-bench-press.jpg",
    meta: "胸部 · 3组 · 8–10次 · 休息180秒",
    sets: [],
  },
};

class MockBridge implements FitTrackBridge {
  private snapshot = structuredClone(mockSnapshot);

  async getSnapshot() {
    return structuredClone(this.snapshot);
  }

  async updateSet(setId: string, weightKg: number, reps: number) {
    const set = this.snapshot.current.sets.find((item) => item.id === setId);
    if (set) Object.assign(set, { weightKg, reps });
  }

  async completeSet(setId: string) {
    const sets = this.snapshot.current.sets;
    const currentIndex = sets.findIndex((item) => item.id === setId);
    if (currentIndex < 0) return;
    sets[currentIndex].state = "completed";
    const next = sets[currentIndex + 1];
    if (next) next.state = "active";
    this.snapshot.completedSets += 1;
    this.snapshot.restRunning = true;
    this.snapshot.restSeconds = 120;
  }

  async addSet() {
    const first = this.snapshot.current.sets[0];
    this.snapshot.current.sets.push({
      id: `set-${crypto.randomUUID()}`,
      number: this.snapshot.current.sets.length + 1,
      weightKg: first?.weightKg ?? 0,
      reps: first?.reps ?? 0,
      state: "pending",
    });
  }

  async openNextExercise() {}
  async pauseRest() {
    this.snapshot.restRunning = !this.snapshot.restRunning;
  }
  async skipRest() {
    this.snapshot.restRunning = false;
    this.snapshot.restSeconds = 0;
  }
}

declare global {
  interface Window {
    fitTrackBridge?: FitTrackBridge;
    qt?: { webChannelTransport?: unknown };
    QWebChannel?: new (
      transport: unknown,
      ready: (channel: { objects: Record<string, QtRemoteObject> }) => void,
    ) => unknown;
  }
}

type QtRemoteMethod = (...args: unknown[]) => void;
type QtRemoteObject = Record<string, unknown | QtRemoteMethod>;

function qtInvoke<T>(target: QtRemoteObject, method: string, ...args: unknown[]): Promise<T> {
  return new Promise((resolve, reject) => {
    const remoteMethod = target[method];
    if (typeof remoteMethod !== "function") {
      reject(new Error(`Qt bridge method is unavailable: ${method}`));
      return;
    }
    remoteMethod(...args, (result: T) => resolve(result));
  });
}

class QtWebChannelBridge implements FitTrackBridge {
  private currentExerciseIndex = 0;

  constructor(
    private readonly workout: QtRemoteObject,
    private readonly timer: QtRemoteObject,
  ) {}

  private exercises() {
    return Array.isArray(this.workout.exercises)
      ? (this.workout.exercises as Record<string, unknown>[])
      : [];
  }

  private sets(exercise: Record<string, unknown>) {
    return Array.isArray(exercise.sets)
      ? (exercise.sets as Record<string, unknown>[])
      : [];
  }

  private firstIncompleteIndex(exercises: Record<string, unknown>[]) {
    return Math.max(0, exercises.findIndex((exercise) =>
      this.sets(exercise).some((set) => !Boolean(set.completed)),
    ));
  }

  private exerciseAt(index: number) {
    return this.exercises()[index];
  }

  private setPosition(setId: string) {
    for (let exerciseIndex = 0; exerciseIndex < this.exercises().length; exerciseIndex += 1) {
      const setIndex = this.sets(this.exercises()[exerciseIndex]).findIndex(
        (set) => String(set.id) === setId,
      );
      if (setIndex >= 0) return { exerciseIndex, setIndex };
    }
    return null;
  }

  async getSnapshot(): Promise<WorkoutSnapshot> {
    const exercises = this.exercises();
    if (!this.exerciseAt(this.currentExerciseIndex)) {
      this.currentExerciseIndex = this.firstIncompleteIndex(exercises);
    }
    const current = this.exerciseAt(this.currentExerciseIndex) ?? {};
    const currentSets = this.sets(current);
    const activeSetIndex = currentSets.findIndex((set) => !Boolean(set.completed));
    const nextExerciseIndex = exercises.findIndex(
      (exercise, index) => index > this.currentExerciseIndex
        && this.sets(exercise).some((set) => !Boolean(set.completed)),
    );
    const next = nextExerciseIndex >= 0 ? exercises[nextExerciseIndex] : null;

    const completedSets = exercises.flatMap((exercise) => this.sets(exercise))
      .filter((set) => Boolean(set.completed));
    const totalVolume = completedSets.reduce((sum, set) => {
      const sideFactor = Boolean(set.bothSides) ? 2 : 1;
      return sum + Number(set.weightKg || 0) * Number(set.actualReps || 0) * sideFactor;
    }, 0);

    const toExercise = (exercise: Record<string, unknown>, index: number): ExerciseSummary => ({
      id: String(exercise.id || `exercise-${index}`),
      name: String(exercise.name || "训练动作"),
      image: index === this.currentExerciseIndex
        ? "./images/incline-dumbbell-bench-press.jpg"
        : "./images/barbell-bench-press.jpg",
      meta: `${this.sets(exercise).length}组 · ${String(exercise.recommendedReps || "自定次数")} · 休息${Number(exercise.restSeconds || 0)}秒`,
      notes: String(exercise.notes || ""),
      sets: this.sets(exercise).map((set, setIndex) => ({
        id: String(set.id || `${index}-${setIndex}`),
        number: Number(set.number || setIndex + 1),
        weightKg: Number(set.weightKg || 0),
        reps: Number(Boolean(set.completed) ? set.actualReps : set.targetReps) || 0,
        state: Boolean(set.completed)
          ? "completed"
          : setIndex === activeSetIndex ? "active" : "pending",
      })),
    });

    const restSeconds = Number(this.timer.remainingSeconds || current.restSeconds || 0);
    return {
      title: "记录训练",
      progress: `${String(this.workout.sessionName || "训练")} · 第${this.currentExerciseIndex + 1}/${exercises.length}个动作`,
      elapsed: "进行中",
      totalVolume: `${Math.round(totalVolume).toLocaleString("zh-CN")} kg`,
      completedSets: completedSets.length,
      restSeconds,
      restRunning: Number(this.timer.state || 0) === 1,
      current: toExercise(current, this.currentExerciseIndex),
      next: next ? toExercise(next, nextExerciseIndex) : null,
    };
  }

  async updateSet(setId: string, weightKg: number, reps: number) {
    const position = this.setPosition(setId);
    if (!position) return;
    await qtInvoke<boolean>(this.workout, "setSetWeight", position.exerciseIndex, position.setIndex, weightKg);
    await qtInvoke<boolean>(this.workout, "setTargetReps", position.exerciseIndex, position.setIndex, reps);
  }

  async completeSet(setId: string) {
    const position = this.setPosition(setId);
    if (!position) return;
    const exercise = this.exerciseAt(position.exerciseIndex) ?? {};
    const set = this.sets(exercise)[position.setIndex] ?? {};
    await qtInvoke<boolean>(
      this.workout,
      "completeSet",
      position.exerciseIndex,
      position.setIndex,
      Number(set.weightKg || 0),
      Number(set.targetReps || 0),
      false,
      "Bodyweight",
    );
  }

  async addSet() {
    const current = this.exerciseAt(this.currentExerciseIndex) ?? {};
    const first = this.sets(current)[0] ?? {};
    await qtInvoke<boolean>(
      this.workout,
      "addSetFromFirstSet",
      this.currentExerciseIndex,
      first.weightKg ?? null,
      first.completed ? first.actualReps ?? null : first.targetReps ?? null,
    );
  }

  async openNextExercise() {
    const exercises = this.exercises();
    const nextIndex = exercises.findIndex(
      (exercise, index) => index > this.currentExerciseIndex
        && this.sets(exercise).some((set) => !Boolean(set.completed)),
    );
    if (nextIndex >= 0) this.currentExerciseIndex = nextIndex;
  }

  async pauseRest() {
    await qtInvoke<void>(this.timer, Number(this.timer.state || 0) === 2 ? "resume" : "pause");
  }

  async skipRest() {
    await qtInvoke<void>(this.timer, "reset");
  }
}

export async function resolveBridge(): Promise<FitTrackBridge> {
  if (window.fitTrackBridge) return window.fitTrackBridge;
  if (window.qt?.webChannelTransport && window.QWebChannel) {
    return new Promise((resolve) => {
      new window.QWebChannel!(window.qt!.webChannelTransport!, (channel) => {
        resolve(new QtWebChannelBridge(
          channel.objects.workoutController,
          channel.objects.restTimer,
        ));
      });
    });
  }
  return new MockBridge();
}
