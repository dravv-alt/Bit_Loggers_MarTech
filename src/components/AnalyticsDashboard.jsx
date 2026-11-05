import React, { useState, useEffect } from 'react';
import { 
  BarChart3, 
  TrendingUp, 
  ArrowUpRight, 
  ArrowDownRight, 
  Filter, 
  Layers, 
  DollarSign, 
  Percent, 
  RefreshCw,
  Award
} from 'lucide-react';
import { api } from '../api.js';

export default function AnalyticsDashboard({ currentUser, showToast }) {
  const [channelFilter, setChannelFilter] = useState('All');
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchAnalytics = async () => {
    try {
      setLoading(true);
      const res = await api.getAnalytics(channelFilter, currentUser);
      setData(res);
    } catch (err) {
      showToast(err.message, 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAnalytics();
  }, [channelFilter, currentUser?.id]);

  if (loading && !data) {
    return (
      <div className="text-center py-16 text-cyan-400 text-xs">
        Compiling MarTech intelligence metrics…
      </div>
    );
  }

  const kpis = data?.summary?.kpis || {};
  const channelBreakdown = data?.channelBreakdown || [];

  return (
    <div className="space-y-6">
      {/* Top Filter and Overview Header */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 glass-panel rounded-2xl border border-slate-800">
        <div>
          <div className="flex items-center gap-2">
            <BarChart3 className="w-5 h-5 text-cyan-400" />
            <h2 className="text-base font-extrabold text-slate-100 tracking-tight">
              Pillar 2: Intelligence & Performance Analytics
            </h2>
          </div>
          <p className="text-xs text-slate-400 pt-0.5">
            5 Mandatory MarTech KPIs comparing Projected targets against Actual marketing return.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1.5">
            <Filter className="w-3.5 h-3.5 text-slate-400" />
            <select
              value={channelFilter}
              onChange={(e) => setChannelFilter(e.target.value)}
              className="bg-slate-800 border border-slate-700 text-slate-200 text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-cyan-500"
            >
              <option value="All">All Channels</option>
              <option value="Social">Social</option>
              <option value="Email">Email</option>
              <option value="Search">Search</option>
              <option value="Display">Display</option>
              <option value="Influencer">Influencer</option>
              <option value="Video">Video</option>
            </select>
          </div>

          <button
            onClick={fetchAnalytics}
            className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-white transition-colors"
            title="Refresh Metrics"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Summary KPI Ribbon: The 5 Mandatory KPIs */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3.5">
        {[
          { key: 'conversionRate', label: 'Conversion Rate', unit: '%', icon: Percent, color: 'text-cyan-400' },
          { key: 'ctr', label: 'Click-Through Rate', unit: '%', icon: TrendingUp, color: 'text-blue-400' },
          { key: 'roi', label: 'Return on Investment', unit: 'x', icon: Award, color: 'text-emerald-400' },
          { key: 'cpa', label: 'Cost Per Acquisition', unit: '$', icon: DollarSign, color: 'text-amber-400' },
          { key: 'aov', label: 'Average Order Value', unit: '$', icon: DollarSign, color: 'text-purple-400' }
        ].map(item => {
          const kpi = kpis[item.key] || {};
          const proj = kpi.projected || 0;
          const act = kpi.actual || 0;
          const diff = proj > 0 ? (((act - proj) / proj) * 100).toFixed(1) : 0;
          const isPositive = Number(diff) >= 0;
          // For CPA lower is better
          const isFavorable = item.key === 'cpa' ? !isPositive : isPositive;

          return (
            <div key={item.key} className="glass-card p-4 rounded-xl border border-slate-800 space-y-2">
              <div className="flex items-center justify-between text-xs text-slate-400">
                <span className="font-semibold">{item.label}</span>
                <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded flex items-center gap-0.5 ${
                  isFavorable ? 'bg-emerald-500/20 text-emerald-300' : 'bg-red-500/20 text-red-300'
                }`}>
                  {isPositive ? <ArrowUpRight className="w-3 h-3" /> : <ArrowDownRight className="w-3 h-3" />}
                  {Math.abs(diff)}%
                </span>
              </div>

              {/* Actual Metric Value */}
              <div className="flex items-baseline gap-1 font-mono">
                {item.unit === '$' && <span className="text-slate-400 text-sm">$</span>}
                <span className={`text-2xl font-extrabold ${item.color}`}>
                  {act}
                </span>
                {item.unit !== '$' && <span className="text-slate-400 text-xs">{item.unit}</span>}
              </div>

              {/* Projected Target Reference */}
              <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-[11px] text-slate-400">
                <span>Target projected:</span>
                <span className="font-mono text-slate-300">
                  {item.unit === '$' ? `$${proj}` : `${proj}${item.unit}`}
                </span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Channel Performance Breakdown Table */}
      <div className="glass-panel p-5 rounded-2xl border border-slate-800 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-bold text-slate-200">
            Channel Economics & Yield Comparison
          </h3>
          <span className="text-xs text-slate-400">
            Total Budget: <strong className="text-emerald-400 font-mono">${(data?.summary?.totalBudget || 0).toLocaleString()}</strong>
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-900/80 border-b border-slate-800 text-xs font-semibold text-slate-400">
              <tr>
                <th className="p-3">Channel</th>
                <th className="p-3">Campaigns</th>
                <th className="p-3">Total Budget</th>
                <th className="p-3">Average ROI</th>
                <th className="p-3">Average Conv. Rate</th>
                <th className="p-3 text-right">Yield Efficiency</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {channelBreakdown.length === 0 ? (
                <tr>
                  <td colSpan={6} className="p-6 text-center text-slate-500">
                    No channel breakdown data available.
                  </td>
                </tr>
              ) : (
                channelBreakdown.map(ch => (
                  <tr key={ch.channel} className="hover:bg-slate-800/40 transition-colors">
                    <td className="p-3 font-sans font-bold text-slate-200">
                      {ch.channel}
                    </td>
                    <td className="p-3 font-mono text-slate-300">
                      {ch.count}
                    </td>
                    <td className="p-3 text-emerald-400 font-bold">
                      ${ch.budget.toLocaleString()}
                    </td>
                    <td className="p-3 text-cyan-300">
                      {ch.roi}x
                    </td>
                    <td className="p-3 text-blue-300">
                      {ch.conv}%
                    </td>
                    <td className="p-3 text-right">
                      <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
                        {ch.roi >= 4.0 ? 'HIGH YIELD' : 'STABLE'}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

