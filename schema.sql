-- 词条信息表
CREATE TABLE IF NOT EXISTS expr_info (
    expr_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    update_at    INTEGER NOT NULL,
    user_id      INTEGER NOT NULL,
    version      INTEGER NOT NULL
);
-- 词条内容表，支持全文搜索
CREATE VIRTUAL TABLE IF NOT EXISTS expr_body USING fts4(
    context      TEXT NOT NULL,
    phrase       TEXT NOT NULL,
    description  TEXT NOT NULL,
    tokenize=unicode61
);
-- 历史记录表
CREATE TABLE IF NOT EXISTS history (
    history_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    expr_id      INTEGER NOT NULL,
    context      TEXT NOT NULL,
    phrase       TEXT NOT NULL,
    description  TEXT NOT NULL,
    update_at    INTEGER NOT NULL,
    user_id      INTEGER NOT NULL,
    version      INTEGER NOT NULL
);
-- 用户表
CREATE TABLE IF NOT EXISTS users (
    user_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT NOT NULL
);
-- 评论表
CREATE TABLE IF NOT EXISTS comments (
    comment_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id      INTEGER NOT NULL,
    expr_id      INTEGER NOT NULL,
    version      INTEGER NOT NULL,
    create_at    INTEGER NOT NULL,
    content      TEXT NOT NULL
);
-- 贡献表
CREATE TABLE IF NOT EXISTS contributes (
    expr_id      INTEGER NOT NULL,
    user_id      INTEGER NOT NULL
)