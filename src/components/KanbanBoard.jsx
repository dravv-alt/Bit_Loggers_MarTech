import React, { useState } from 'react';
import { 
  Plus, 
  Search, 
  Filter, 
  Clock, 
  CheckCircle2, 
  AlertCircle, 
  XCircle, 
  Calendar, 
  Lock, 
  ArrowRight, 
  TrendingUp, 
  DollarSign,
  Percent,
  Layers,
  Sparkles,
  FileEdit
} from 'lucide-react';

const COLUMNS = [
  { id: 'Draft', title: 'Draft', color: 'border-slate-600/40 text-slate-400 bg-slate-800/40', badge: 'bg-slate-700/60 text-slate-300' },
  { id: 'Submitted', title: 'Awaiting Review', color: 'border-amber-500/40 text-amber-400 bg-amber-500/5', badge: 'bg-amber-500/20 text-amber-300' },
  { id: 'ChangesRequested', title: 'Changes Requested', color: 'border-orange-500/40 text-orange-400 bg-orange-500/5', badge: 'bg-orange-500/20 text-orange-300' },
  { id: 'Approved', title: 'Approved (Ready)', color: 'border-cyan-500/40 text-cyan-400 bg-cyan-500/5', badge: 'bg-cyan-500/20 text-cyan-300' },
  { id: 'Scheduled', title: 'Scheduled Flights', color: 'border-emerald-500/40 text-emerald-400 bg-emerald-500/5', badge: 'bg-emerald-500/20 text-emerald-300' },
  { id: 'Rejected', title: 'Rejected', color: 'border-red-500/40 text-red-400 bg-red-500/5', badge: 'bg-red-500/20 text-red-300' }
];

const CHANNEL_COLORS = {
  Social: 'bg-pink-500/20 text-pink-300 border-pink-500/30',
  Email: 'bg-blue-500/20 text-blue-300 border-blue-500/30',
  Search: 'bg-amber-500/20 text-amber-300 border-amber-500/30',
  Display: 'bg-purple-500/20 text-purple-300 border-purple-500/30',
  Influencer: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30',
  Video: 'bg-red-500/20 text-red-300 border-red-500/30'
};

export default function KanbanBoard({ 
  campaigns = [], 
  currentUser, 
  onSelectCampaign, 
  onNewCampaign, 
  onSubmitCampaign,
  onOpenScheduleModal
}) {
  const [searchQuery, setSearchQuery] = useState('');
  const [channelFilter, setChannelFilter] = useState('All');

  const filteredCampaigns = campaigns.filter(c => {
    const matchesSearch = c.title.toLowerCase().includes(searchQuery.toLowerCase()) || 
                          c.objective?.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesChannel = channelFilter === 'All' || c.channel === channelFilter;
    return matchesSearch && matchesChannel;
  });

  return (
    <div className="space-y-4">
      {/* Top Filter and Actions Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 p-3 glass-panel rounded-xl">
        <div className="flex items-center gap-2 flex-1 min-w-[200px]">
          <div className="relative flex-1 max-w-sm">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
            <input
              type="text"
              placeholder="Search campaigns, audiences, objectives..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 bg-slate-800/80 border border-slate-700 rounded-lg text-xs text-slate-200 placeholder:text-slate-500 focus:outline-none focus:border-cyan-500"
            />
          </div>

          <div className="flex items-center gap-1.5">
            <Filter className="w-3.5 h-3.5 text-slate-400" />
            <select
              value={channelFilter}
              onChange={(e) => setChannelFilter(e.target.value)}
              className="bg-slate-800/80 border border-slate-700 text-slate-300 text-xs rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-cyan-500"
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
        </div>

        <div className="flex items-center gap-2 text-xs text-slate-400">
          <span>{filteredCampaigns.length} campaigns listed</span>
        </div>
      </div>

      {/* Kanban Board Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4 overflow-x-auto pb-4">
        {COLUMNS.map(col => {
          const colCampaigns = filteredCampaigns.filter(c => {
            if (col.id === 'Draft') return c.status === 'Draft' || c.status === 'Revised';
            return c.status === col.id;
          });

          return (
            <div 
              key={col.id} 
              className="flex flex-col rounded-xl glass-panel border border-slate-800 p-3 min-w-[260px] h-[calc(100vh-220px)] max-h-[750px]"
            >
              {/* Column Header */}
              <div className="flex items-center justify-between pb-3 mb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <h3 className="font-bold text-xs uppercase tracking-wider text-slate-200">
                    {col.title}
                  </h3>
                  <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full ${col.badge}`}>
                    {colCampaigns.length}
                  </span>
                </div>
              </div>

              {/* Cards Container */}
              <div className="flex-1 overflow-y-auto space-y-3 pr-1">
                {colCampaigns.length === 0 ? (
                  <div className="h-28 border border-dashed border-slate-800 rounded-xl flex items-center justify-center text-[11px] text-slate-500">
                    No campaigns
                  </div>
                ) : (
                  colCampaigns.map(camp => {
                    const kpi = camp.kpi_projected || {};
                    const isOwner = currentUser?.id === camp.owner_id;
                    const isReviewer = currentUser?.role === 'reviewer';

                    return (
                      <div
                        key={camp.campaign_id}
                        onClick={() => onSelectCampaign(camp.campaign_id)}
                        className="glass-card rounded-xl p-3.5 space-y-2.5 cursor-pointer transition-all hover:translate-y-[-2px] hover:shadow-lg hover:shadow-cyan-500/10 border border-slate-800 relative group"
                      >
                        {/* Title and Version badge */}
                        <div className="flex items-start justify-between gap-2">
                          <h4 className="font-bold text-xs text-slate-100 group-hover:text-cyan-400 transition-colors line-clamp-2">
                            {camp.title}
                          </h4>
                          <span className="shrink-0 px-1.5 py-0.5 text-[10px] font-mono font-bold bg-slate-800 text-cyan-300 border border-cyan-500/30 rounded-md">
                            v{camp.version_no || 1}
                          </span>
                        </div>

                        {/* Channel & Budget Tags */}
                        <div className="flex items-center justify-between text-[11px]">
                          <span className={`px-2 py-0.5 rounded-md font-medium border text-[10px] ${CHANNEL_COLORS[camp.channel] || 'bg-slate-800 text-slate-300'}`}>
                            {camp.channel || 'Omnichannel'}
                          </span>
                          <span className="font-mono font-bold text-slate-200">
                            ${(camp.budget || 0).toLocaleString()}
                          </span>
                        </div>

                        {/* Audience snippet */}
                        <p className="text-[11px] text-slate-400 line-clamp-2 leading-relaxed">
                          {camp.target_audience || camp.objective}
                        </p>

                        {/* Projected 5 KPIs Mini-Ribbon */}
                        <div className="grid grid-cols-2 gap-1.5 py-1.5 px-2 rounded-lg bg-slate-900/60 border border-slate-800/60 text-[10px] font-mono">
                          <div className="flex items-center justify-between text-slate-400">
                            <span>ROI:</span>
                            <span className="font-bold text-emerald-400">{kpi.roi ? `${kpi.roi}x` : '3.8x'}</span>
                          </div>
                          <div className="flex items-center justify-between text-slate-400">
                            <span>Conv:</span>
                            <span className="font-bold text-cyan-400">{kpi.conversionRate ? `${kpi.conversionRate}%` : '3.5%'}</span>
                          </div>
                        </div>

                        {/* Footer & Quick Actions */}
                        <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-[10px]">
                          <span className="text-slate-500 truncate max-w-[110px]">
                            by {camp.owner_name?.split(' ')[0]}
                          </span>

                          <div className="flex items-center gap-1.5">
                            {/* Role-based Smart CTAs */}
                            {camp.status === 'Submitted' && isReviewer && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  onSelectCampaign(camp.campaign_id);
                                }}
                                className="px-2 py-1 rounded bg-amber-500/20 text-amber-300 hover:bg-amber-500/30 font-bold border border-amber-500/40"
                              >
                                Review
                              </button>
                            )}

                            {(camp.status === 'Draft' || camp.status === 'Revised') && isOwner && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  onSubmitCampaign(camp.campaign_id);
                                }}
                                className="px-2 py-1 rounded bg-cyan-500/20 text-cyan-300 hover:bg-cyan-500/30 font-bold border border-cyan-500/40"
                              >
                                Submit
                              </button>
                            )}

                            {camp.status === 'Approved' && isOwner && (
                              <button
                                onClick={(e) => {
                                  e.stopPropagation();
                                  onOpenScheduleModal(camp);
                                }}
                                className="px-2 py-1 rounded bg-emerald-500/20 text-emerald-300 hover:bg-emerald-500/30 font-bold border border-emerald-500/40"
                              >
                                Schedule
                              </button>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
