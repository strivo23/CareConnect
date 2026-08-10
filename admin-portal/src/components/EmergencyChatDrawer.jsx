import React, { useState, useEffect, useRef } from 'react';
import {
  MdClose,
  MdSend,
  MdAttachFile,
  MdImage,
  MdLocationOn,
  MdWarning,
  MdSearch,
  MdShield,
  MdPerson,
  MdCheckCircle,
  MdLock
} from 'react-icons/md';
import { sosService } from '../services/api';

export default function EmergencyChatDrawer({ incident, isOpen, onClose }) {
  const [messages, setMessages] = useState([]);
  const [newMessage, setNewMessage] = useState('');
  const [searchQuery, setSearchQuery] = useState('');
  const [wsConnected, setWsConnected] = useState(false);
  const [typingUser, setTypingUser] = useState('');
  const messagesEndRef = useRef(null);
  const socketRef = useRef(null);

  const isClosed = ['CLOSED', 'Closed'].includes(incident?.current_status || incident?.status);

  useEffect(() => {
    if (isOpen && incident) {
      fetchChatHistory();
      connectWebSocket();
    }
    return () => {
      if (socketRef.current) {
        socketRef.current.close();
      }
    };
  }, [isOpen, incident]);

  useEffect(() => {
    scrollToBottom();
  }, [messages, typingUser]);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const fetchChatHistory = async () => {
    try {
      const res = await sosService.getChatHistory(incident.id, { search: searchQuery });
      const msgs = res.data?.results || res.data || [];
      setMessages(msgs);
    } catch (err) {
      console.error('Error fetching chat history:', err);
    }
  };

  const connectWebSocket = () => {
    const token = localStorage.getItem('access_token');
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.hostname}:8000/ws/incidents/${incident.id}/chat/?token=${token}`;
    
    try {
      const ws = new WebSocket(wsUrl);
      socketRef.current = ws;

      ws.onopen = () => {
        setWsConnected(true);
      };

      ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        if (data.type === 'chat_message') {
          setMessages((prev) => [...prev, data.message]);
        } else if (data.type === 'typing_status') {
          if (data.is_typing) {
            setTypingUser(data.user_name);
          } else {
            setTypingUser('');
          }
        }
      };

      ws.onclose = () => {
        setWsConnected(false);
      };

      ws.onerror = (err) => {
        console.error('WebSocket Error:', err);
        setWsConnected(false);
      };
    } catch (e) {
      console.error('WS Connection error:', e);
    }
  };

  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!newMessage.trim() || isClosed) return;

    const payload = {
      message: newMessage,
      message_type: 'TEXT'
    };

    if (wsConnected && socketRef.current) {
      socketRef.current.send(JSON.stringify({
        action: 'chat_message',
        ...payload
      }));
      setNewMessage('');
    } else {
      try {
        const res = await sosService.sendChatMessage(incident.id, payload);
        if (res.data?.message) {
          setMessages((prev) => [...prev, res.data.message]);
        }
        setNewMessage('');
      } catch (err) {
        alert(err.response?.data?.error || 'Failed to send message.');
      }
    }
  };

  if (!isOpen || !incident) return null;

  const filteredMessages = searchQuery
    ? messages.filter((m) => m.message?.toLowerCase().includes(searchQuery.toLowerCase()))
    : messages;

  return (
    <div className="fixed inset-0 z-50 overflow-hidden bg-slate-900/40 backdrop-blur-sm flex justify-end">
      <div className="w-full max-w-lg bg-white dark:bg-slate-900 h-full shadow-2xl flex flex-col border-l border-slate-200 dark:border-slate-800 animate-in slide-in-from-right duration-300">
        
        {/* Header */}
        <div className="p-4 border-b border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-850 flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-red-100 dark:bg-red-900/40 rounded-lg text-red-600 dark:text-red-400">
              <MdShield className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <h3 className="font-bold text-slate-900 dark:text-white">Emergency Chat #{incident.id}</h3>
                <span className={`px-2 py-0.5 text-xs font-semibold rounded-full ${
                  isClosed ? 'bg-slate-200 text-slate-700' : 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400'
                }`}>
                  {incident.current_status || incident.status}
                </span>
              </div>
              <p className="text-xs text-slate-500 flex items-center gap-1.5 mt-0.5">
                <span className={`w-2 h-2 rounded-full ${wsConnected ? 'bg-emerald-500' : 'bg-amber-500'}`}></span>
                {wsConnected ? 'Live Connection' : 'Polling Sync'}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 rounded-lg hover:bg-slate-200 dark:hover:bg-slate-800"
          >
            <MdClose className="w-5 h-5" />
          </button>
        </div>

        {/* Participants Bar */}
        <div className="px-4 py-2 bg-slate-100 dark:bg-slate-800/60 border-b border-slate-200 dark:border-slate-700/50 flex items-center justify-between text-xs">
          <div className="flex items-center space-x-3">
            <span className="text-slate-500 font-medium">Participants:</span>
            <span className="bg-blue-100 text-blue-800 px-2 py-0.5 rounded font-semibold flex items-center gap-1">
              <MdPerson className="w-3.5 h-3.5" /> {incident.resident_name || incident.resident?.full_name || 'Resident'}
            </span>
            {incident.assigned_responder && (
              <span className="bg-purple-100 text-purple-800 px-2 py-0.5 rounded font-semibold flex items-center gap-1">
                <MdCheckCircle className="w-3.5 h-3.5" /> {incident.assigned_responder.full_name || incident.assigned_role}
              </span>
            )}
          </div>
        </div>

        {/* Search Bar */}
        <div className="p-2 border-b border-slate-100 dark:border-slate-800">
          <div className="relative">
            <MdSearch className="w-4 h-4 absolute left-3 top-2.5 text-slate-400" />
            <input
              type="text"
              placeholder="Search chat messages..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3 py-1.5 text-xs bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-md focus:outline-none focus:ring-1 focus:ring-red-500"
            />
          </div>
        </div>

        {/* Messages Feed */}
        <div className="flex-1 overflow-y-auto p-4 space-y-3 bg-slate-50/50 dark:bg-slate-900/50">
          {filteredMessages.map((msg, index) => {
            const isSystem = msg.message_type === 'SYSTEM' || msg.sender_role === 'SYSTEM';

            if (isSystem) {
              return (
                <div key={msg.id || index} className="flex justify-center my-2">
                  <span className="bg-slate-200/80 dark:bg-slate-800 text-slate-600 dark:text-slate-300 text-xs px-3 py-1 rounded-full font-medium shadow-sm border border-slate-300/40 dark:border-slate-700 flex items-center gap-1">
                    <MdWarning className="w-3.5 h-3.5 text-amber-500" /> {msg.message}
                  </span>
                </div>
              );
            }

            const isMine = msg.sender_role === 'ADMIN';

            return (
              <div
                key={msg.id || index}
                className={`flex flex-col ${isMine ? 'items-end' : 'items-start'}`}
              >
                <div className="flex items-center space-x-1.5 mb-1 px-1">
                  <span className="text-xs font-bold text-slate-700 dark:text-slate-300">
                    {msg.sender_name || 'User'}
                  </span>
                  <span className="text-[10px] uppercase tracking-wider px-1.5 py-0.2 rounded font-extrabold bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300">
                    {msg.sender_role}
                  </span>
                  <span className="text-[10px] text-slate-400">
                    {new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                </div>

                <div className={`max-w-[85%] rounded-2xl px-4 py-2.5 text-sm shadow-sm ${
                  isMine
                    ? 'bg-red-600 text-white rounded-br-none'
                    : 'bg-white dark:bg-slate-800 text-slate-900 dark:text-white border border-slate-200 dark:border-slate-700 rounded-bl-none'
                }`}>
                  {msg.reply_to_detail && (
                    <div className="mb-2 p-1.5 rounded bg-black/10 dark:bg-white/10 text-xs border-l-2 border-amber-400">
                      <span className="font-semibold">{msg.reply_to_detail.sender_name}</span>
                      <p className="truncate opacity-80">{msg.reply_to_detail.message}</p>
                    </div>
                  )}

                  {msg.message && <p className="whitespace-pre-wrap">{msg.message}</p>}

                  {msg.latitude && msg.longitude && (
                    <a
                      href={`https://maps.google.com/?q=${msg.latitude},${msg.longitude}`}
                      target="_blank"
                      rel="noreferrer"
                      className="mt-2 flex items-center gap-1.5 text-xs font-semibold underline text-amber-300"
                    >
                      <MdLocationOn className="w-4 h-4" /> View GPS Location ({msg.latitude}, {msg.longitude})
                    </a>
                  )}

                  {msg.attachment && (
                    <div className="mt-2">
                      {msg.message_type === 'IMAGE' ? (
                        <img src={msg.attachment} alt="Attachment" className="max-h-40 rounded-lg object-cover" />
                      ) : (
                        <a href={msg.attachment} target="_blank" rel="noreferrer" className="underline text-xs flex items-center gap-1">
                          <MdAttachFile className="w-3.5 h-3.5" /> View Attachment
                        </a>
                      )}
                    </div>
                  )}
                </div>
              </div>
            );
          })}

          {typingUser && (
            <div className="text-xs italic text-slate-500 flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-slate-400 animate-pulse"></span>
              {typingUser} is typing...
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Input Bar */}
        {isClosed ? (
          <div className="p-4 bg-slate-100 dark:bg-slate-800/80 border-t border-slate-200 dark:border-slate-800 text-center text-slate-600 dark:text-slate-300 text-xs font-semibold flex items-center justify-center gap-2">
            <MdLock className="w-4 h-4 text-slate-500" /> Incident is Closed. Chat is read-only.
          </div>
        ) : (
          <form onSubmit={handleSendMessage} className="p-3 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center space-x-2">
            <input
              type="text"
              placeholder="Type emergency response message..."
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              className="flex-1 px-4 py-2.5 text-sm bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl focus:outline-none focus:ring-2 focus:ring-red-500 text-slate-900 dark:text-white"
            />
            <button
              type="submit"
              disabled={!newMessage.trim()}
              className="p-2.5 bg-red-600 hover:bg-red-700 disabled:opacity-50 text-white rounded-xl shadow-md transition-all flex items-center justify-center"
            >
              <MdSend className="w-4 h-4" />
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
