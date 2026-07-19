import { StrictMode, useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import {
  type FitTrackBridge,
  type WorkoutSet,
  type WorkoutSnapshot,
  resolveBridge,
} from "./bridge";
import "./styles.css";

function formatRest(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  return `${String(minutes).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
}

function SetRow({
  item,
  onChange,
  onComplete,
}: {
  item: WorkoutSet;
  onChange: (setId: string, weightKg: number, reps: number) => void;
  onComplete: (setId: string) => void;
}) {
  const editable = item.state === "active";
  return (
    <div className={`set-row ${item.state}`}>
      <span className="set-number">{item.number}</span>
      <span className="previous">—</span>
      {editable ? (
        <input
          aria-label={`第${item.number}组重量`}
          inputMode="decimal"
          value={item.weightKg}
          onChange={(event) => onChange(item.id, Number(event.target.value), item.reps)}
        />
      ) : (
        <span className="set-value">{item.weightKg}</span>
      )}
      {editable ? (
        <input
          aria-label={`第${item.number}组次数`}
          inputMode="numeric"
          value={item.reps}
          onChange={(event) => onChange(item.id, item.weightKg, Number(event.target.value))}
        />
      ) : (
        <span className="set-value">{item.reps}</span>
      )}
      <button
        className="set-status"
        aria-label={item.state === "completed" ? `第${item.number}组已完成` : `完成第${item.number}组`}
        disabled={item.state === "pending"}
        onClick={() => onComplete(item.id)}
      >
        {item.state === "completed" ? "✓" : ""}
      </button>
    </div>
  );
}

function App() {
  const [bridge, setBridge] = useState<FitTrackBridge>();
  const [snapshot, setSnapshot] = useState<WorkoutSnapshot>();

  useEffect(() => {
    resolveBridge().then(async (resolved) => {
      setBridge(resolved);
      setSnapshot(await resolved.getSnapshot());
    });
  }, []);

  const activeSet = useMemo(
    () => snapshot?.current.sets.find((item) => item.state === "active"),
    [snapshot],
  );

  async function refresh() {
    if (bridge) setSnapshot(await bridge.getSnapshot());
  }

  async function updateSet(setId: string, weightKg: number, reps: number) {
    if (!bridge) return;
    await bridge.updateSet(setId, weightKg, reps);
    await refresh();
  }

  async function completeSet(setId: string) {
    if (!bridge) return;
    await bridge.completeSet(setId);
    await refresh();
  }

  if (!snapshot) return <main className="loading">正在载入训练…</main>;

  return (
    <div className="app-shell">
      <header className="top-bar">
        <button className="icon-button" aria-label="返回">‹</button>
        <div className="title-block">
          <h1>{snapshot.title}</h1>
          <p>{snapshot.progress}</p>
        </div>
        <span className="session-clock">◷ {snapshot.elapsed}</span>
        <button className="finish-button">完成</button>
      </header>

      <section className="summary" aria-label="训练统计">
        <div><span>训练时间</span><strong>{snapshot.elapsed}</strong></div>
        <div><span>总容量</span><strong>{snapshot.totalVolume}</strong></div>
        <div><span>已完成组数</span><strong>{snapshot.completedSets} 组</strong></div>
      </section>

      <main className="content">
        <section className="exercise-card">
          <div className="exercise-header">
            <img src={snapshot.current.image} alt="" />
            <div>
              <span className="eyebrow">当前动作</span>
              <h2>{snapshot.current.name}</h2>
              <p>{snapshot.current.meta}</p>
            </div>
            <button className="more-button" aria-label="更多操作">•••</button>
          </div>
          {snapshot.current.notes && <p className="exercise-note">{snapshot.current.notes}</p>}

          <div className="set-header">
            <span>组</span><span>上次记录</span><span>kg</span><span>次数</span><span>状态</span>
          </div>
          <div className="set-list">
            {snapshot.current.sets.map((item) => (
              <SetRow key={item.id} item={item} onChange={updateSet} onComplete={completeSet} />
            ))}
          </div>
          <button className="add-set" onClick={async () => { await bridge?.addSet(); await refresh(); }}>
            ＋ 添加一组
          </button>

          <div className={`rest-card ${snapshot.restRunning ? "running" : ""}`}>
            <div className="timer-icon">◷</div>
            <div className="rest-copy">
              <span>{snapshot.restRunning ? "休息计时" : "休息时间"}</span>
              <strong>{formatRest(snapshot.restSeconds)}</strong>
            </div>
            {snapshot.restRunning && (
              <>
                <button onClick={async () => { await bridge?.pauseRest(); await refresh(); }}>暂停</button>
                <button onClick={async () => { await bridge?.skipRest(); await refresh(); }}>跳过</button>
              </>
            )}
          </div>
        </section>

        {snapshot.next && (
          <button className="next-preview" onClick={() => bridge?.openNextExercise()}>
            <img src={snapshot.next.image} alt="" />
            <div>
              <span className="eyebrow">接下来</span>
              <h3>{snapshot.next.name}</h3>
              <p>{snapshot.next.meta}</p>
            </div>
            <span className="next-action">查看 ›</span>
          </button>
        )}
      </main>

      <nav className="bottom-nav" aria-label="主导航">
        <span>首页</span><span>训练计划</span><strong>记录</strong><span>历史</span><span>我的</span>
      </nav>
      {activeSet && <div className="active-set-hint">当前第 {activeSet.number} 组</div>}
    </div>
  );
}

createRoot(document.getElementById("root")!).render(
  <StrictMode><App /></StrictMode>,
);
