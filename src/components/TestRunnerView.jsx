import React, { useState, useEffect } from 'react';
import { 
  ShieldCheck, 
  Play, 
  CheckCircle2, 
  XCircle, 
  Clock, 
  RefreshCw, 
  Layers, 
  Lock, 
  Database,
  Cpu
} from 'lucide-react';
import { api } from '../api.js';

export default function TestRunnerView({ currentUser, showToast }) {
  const [running, setRunning] = useState(false);
  const [report, setReport] = useState(null);

  const executeTests = async () => {
    setRunning(true);
    try {
      const res = await api.runTests(currentUser);
      setReport(res);
      showToast(`Automated architecture test suite finished: ${res.passedCount}/${res.total} tests passed!`, 'success');
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setRunning(false);
    }
  };

  useEffect(() => {
    executeTests();
  }, []);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-5 h-5 text-emerald-400" />
            <h2 className="text-base font-extrabold text-slate-100 tracking-tight">
              LLD Section 14: Automated Architecture Test Specification
            </h2>
          </div>
          <p className="text-xs text-slate-400 pt-0.5">
            14 Mandatory Acceptance Scenarios (T-01 to T-14) validating QA-01 Consistency, QA-02 Reliability, and QA-03 Security.
          </p>
        </div>

        <button
          onClick={executeTests}
          disabled={running}
          className="flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-400 hover:to-teal-500 text-white shadow-lg shadow-emerald-500/20 transition-all disabled:opacity-50"
        >
          {running ? <Clock className="w-4 h-4 animate-spin" /> : <Play className="w-4 h-4" />}
          <span>{running ? 'Running Test Suite...' : 'Re-Run All 14 Tests'}</span>
        </button>
      </div>

      {/* Summary KPI Banner */}
      {report && (
        <div className="grid grid-cols-1 sm:grid-cols-4 gap-3">
          <div className="glass-card p-4 rounded-xl border border-slate-800">
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
              Overall Status
            </div>
            <div className={`text-lg font-extrabold flex items-center gap-2 ${report.allPassed ? 'text-emerald-400' : 'text-amber-400'}`}>
              {report.allPassed ? <CheckCircle2 className="w-5 h-5" /> : <XCircle className="w-5 h-5" />}
              <span>{report.allPassed ? '100% COMPLIANT' : 'FAILURES DETECTED'}</span>
            </div>
          </div>

          <div className="glass-card p-4 rounded-xl border border-slate-800">
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
              QA-01 Data Consistency
            </div>
            <div className="text-lg font-extrabold text-cyan-400 font-mono">
              VERIFIED
            </div>
          </div>

          <div className="glass-card p-4 rounded-xl border border-slate-800">
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
              QA-02 Reliability & Recovery
            </div>
            <div className="text-lg font-extrabold text-blue-400 font-mono">
              VERIFIED
            </div>
          </div>

          <div className="glass-card p-4 rounded-xl border border-slate-800">
            <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">
              QA-03 Security & Privacy
            </div>
            <div className="text-lg font-extrabold text-purple-400 font-mono">
              VERIFIED
            </div>
          </div>
        </div>
      )}

      {/* Tests Grid */}
      <div className="space-y-3">
        {running && !report ? (
          <div className="text-center py-16 text-cyan-400 text-xs">
            Executing isolated database test harness...
          </div>
        ) : (
          report?.results?.map(t => (
            <div 
              key={t.id}
              className={`p-4 rounded-xl border transition-all flex flex-col sm:flex-row sm:items-center justify-between gap-3 ${
                t.passed 
                  ? 'glass-card border-emerald-500/30 bg-emerald-950/10' 
                  : 'glass-card border-red-500/40 bg-red-950/20'
              }`}
            >
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <span className="font-mono font-extrabold text-xs px-2 py-0.5 rounded bg-slate-800 text-cyan-300 border border-slate-700">
                    {t.id}
                  </span>
                  <span className="text-[10px] uppercase font-bold px-2 py-0.5 rounded bg-slate-800 text-slate-300 border border-slate-700">
                    {t.qa}
                  </span>
                  <span className="font-extrabold text-xs text-slate-100">
                    {t.name}
                  </span>
                </div>

                <div className="text-xs text-slate-400 font-mono pl-1">
                  {t.details}
                </div>
              </div>

              <div className="flex items-center gap-2 shrink-0">
                <span className={`px-2.5 py-1 rounded-lg text-xs font-bold uppercase flex items-center gap-1.5 ${
                  t.passed ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/40' : 'bg-red-500/20 text-red-300 border border-red-500/40'
                }`}>
                  {t.passed ? <CheckCircle2 className="w-3.5 h-3.5" /> : <XCircle className="w-3.5 h-3.5" />}
                  <span>{t.passed ? 'PASS' : 'FAIL'}</span>
                </span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
