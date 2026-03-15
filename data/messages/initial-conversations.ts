import { Conversation } from "@/types/messages";

const getTimeAgo = (minutes: number) => {
  const date = new Date();
  date.setMinutes(date.getMinutes() - minutes);
  return date.toISOString();
};

export const initialConversations: Conversation[] = [
  {
    id: "a1b2c3d4-0001-0001-0001-000000000001",
    recipients: [
      {
        id: "a1b2c3d4-0002-0002-0002-000000000002",
        name: "小张同学",
      },
    ],
    lastMessageTime: getTimeAgo(2),
    unreadCount: 1,
    pinned: true,
    messages: [
      {
        id: "a1b2c3d4-0003-0003-0003-000000000003",
        content: "你好！",
        sender: "me",
        timestamp: getTimeAgo(3),
      },
      {
        id: "a1b2c3d4-0004-0004-0004-000000000004",
        content: "嗨～我是小张同学，泽旭的 AI 分身 😄 有什么想了解他的，尽管问！",
        sender: "小张同学",
        timestamp: getTimeAgo(2),
      },
    ],
  },
];
