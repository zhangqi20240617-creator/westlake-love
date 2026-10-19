# -*- coding: utf-8 -*-
"""本地联调用 Mock Server（非游戏运行时依赖）。

⚠️ 与 release 打包的关系：
  - 本文件是 Python，不被 Godot 导出；
  - 但 export_presets.cfg 的 include_filter 含 `*.json`，故 `mock_server_db/` 下的
    联调数据会被打进包 —— 已在 export_presets.cfg 用 exclude_filter 排除。
  - 游戏运行时只通过 HTTP 访问本服务，从不直接读 mock_server_db/ 内的文件。

用法：
  python scripts/mock_server.py                # 默认 8000 端口
  python scripts/mock_server.py --port 8123    # 指定端口（M1）
  MOCK_SERVER_PORT=8123 python scripts/mock_server.py
"""
import argparse
import http.server
import json
import os
import random
import socketserver
import time
import urllib.parse

# ── M1：端口 / 路径可配置（命令行 > 环境变量 > 默认值）────────────
DEFAULT_PORT = 8000
DEFAULT_HOST = ""            # 空串 = 监听所有网卡（真机联调需要）
ENV_PORT = "MOCK_SERVER_PORT"
ENV_DB_DIR = "MOCK_SERVER_DB"

# 属性上限与游戏内一致，种子数据与提交校验共用同一常量（M2 防脏数据回潮）
INTELLECT_MIN = 0
INTELLECT_MAX = 100

# 相对项目根定位，避免依赖调用者的当前工作目录
_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SEED_FILE = os.path.join(_PROJECT_ROOT, "scripts", "mock_seed_data.json")

DB_DIR = os.environ.get(ENV_DB_DIR) or os.path.join(_PROJECT_ROOT, "mock_server_db")
SAVES_DIR = os.path.join(DB_DIR, "saves")
PROFILES_DIR = os.path.join(DB_DIR, "profiles")
LEADERBOARD_FILE = os.path.join(DB_DIR, "leaderboard.json")
WISHES_FILE = os.path.join(DB_DIR, "wishes.json")
CHAT_FILE = os.path.join(DB_DIR, "world_chat.json")


# ── M4：种子数据一律来自 mock_seed_data.json，代码内不写死测试数据 ──
def load_seed():
    try:
        with open(SEED_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        print(f"[mock_server] 种子文件读取失败（将以空数据启动）：{SEED_FILE} -> {exc}")
        return {}


SEED = load_seed()


def _sanitized_leaderboard_seed():
    """M2：种子排行榜过 0-100 校验，越界项直接丢弃并告警，杜绝脏数据入库。"""
    rows = []
    for row in SEED.get("leaderboard", []):
        value = row.get("intellect", 0)
        if not isinstance(value, int) or not (INTELLECT_MIN <= value <= INTELLECT_MAX):
            print(f"[mock_server] 丢弃越界种子数据：{row}")
            continue
        rows.append(row)
    return rows


def _write_json(path, payload):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=4)


def init_db():
    """初始化数据目录与三张表；已存在的数据不覆盖。"""
    os.makedirs(SAVES_DIR, exist_ok=True)
    os.makedirs(PROFILES_DIR, exist_ok=True)

    if not os.path.exists(LEADERBOARD_FILE):
        _write_json(LEADERBOARD_FILE, [])

    if not os.path.exists(CHAT_FILE):
        _write_json(CHAT_FILE, SEED.get("world_chat", []))

    # 心愿表：不存在，或是缺少 id 字段的旧格式，则用种子重建
    need_init = not os.path.exists(WISHES_FILE)
    if not need_init:
        try:
            with open(WISHES_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            if len(data) > 0 and "id" not in data[0]:
                need_init = True
        except Exception:
            need_init = True
    if need_init:
        _write_json(WISHES_FILE, SEED.get("wishes", []))


init_db()

class MockServerHandler(http.server.BaseHTTPRequestHandler):
    def end_headers(self):
        # 允许跨域，方便调试
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def send_json_response(self, code, data):
        response_bytes = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(response_bytes)))
        self.end_headers()
        self.wfile.write(response_bytes)

    def do_GET(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path
        query = urllib.parse.parse_qs(parsed_url.query)

        # ── 1. 获取排行榜 ──
        if path == "/leaderboard":
            try:
                with open(LEADERBOARD_FILE, "r", encoding="utf-8") as f:
                    scores = json.load(f)
                # 按学习（intellect）从高到低排序，限制前10名
                scores.sort(key=lambda x: x.get("intellect", 0), reverse=True)
                top_10 = scores[:10]
                
                self.send_json_response(200, top_10)
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 2. 下载云存档 ──
        elif path == "/cloud_save/download":
            username = query.get("username", [""])[0]
            if not username:
                self.send_error_response(400, "Missing username parameter")
                return

            safe_name = "".join([c for c in username if c.isalpha() or c.isdigit() or c=='_']).rstrip()
            if not safe_name:
                safe_name = "default"
            save_path = os.path.join(SAVES_DIR, f"{safe_name}.json")

            if os.path.exists(save_path):
                try:
                    with open(save_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    self.send_json_response(200, data)
                except Exception as e:
                    self.send_error_response(500, str(e))
            else:
                self.send_error_response(404, "Save file not found")

        # ── 3. 随机拉取许愿漂流瓶 ──
        elif path == "/wishes/random":
            try:
                count_str = query.get("count", ["5"])[0]
                count = int(count_str)
            except ValueError:
                count = 5

            try:
                with open(WISHES_FILE, "r", encoding="utf-8") as f:
                    wishes = json.load(f)

                # 随机采样，若总数不够就全部返回
                sampled = random.sample(wishes, min(len(wishes), count))
                self.send_json_response(200, sampled)
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 4. 拉取我放出的许愿花灯 ──
        elif path == "/wishes/my":
            username = query.get("username", [""])[0]
            if not username:
                self.send_error_response(400, "Missing username parameter")
                return

            try:
                with open(WISHES_FILE, "r", encoding="utf-8") as f:
                    wishes = json.load(f)
                
                # 过滤出 username 匹配的心愿，按最新发布的排在前面
                my_list = [w for w in wishes if w.get("username") == username]
                my_list.reverse()
                self.send_json_response(200, my_list)
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 5. 获取世界聊天历史记录 ──
        elif path == "/chat/history":
            try:
                with open(CHAT_FILE, "r", encoding="utf-8") as f:
                    chat_history = json.load(f)
                self.send_json_response(200, chat_history)
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 6. 获取玩家全局档案（跨周目持久数据）──
        elif path == "/player/profile":
            username = query.get("username", [""])[0]
            if not username:
                self.send_error_response(400, "Missing username parameter")
                return

            safe_name = "".join([c for c in username if c.isalpha() or c.isdigit() or c=='_']).rstrip()
            if not safe_name:
                safe_name = "default"
            profile_path = os.path.join(PROFILES_DIR, f"{safe_name}.json")

            if os.path.exists(profile_path):
                try:
                    with open(profile_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    self.send_json_response(200, data)
                except Exception as e:
                    self.send_error_response(500, str(e))
            else:
                # 首次请求：返回空 profile 默认结构
                default_profile = {
                    "username": username,
                    "ng_count": 0,
                    "unlocked_titles": [],
                    "unlocked_recipes": [],
                    "seen_endings": [],
                    "gallery_flags": [],
                    "inherited_money": 0,
                    "created_at": ""
                }
                self.send_json_response(200, default_profile)

        else:
            self.send_error_response(404, "Endpoint not found")

    def do_POST(self):
        parsed_url = urllib.parse.urlparse(self.path)
        path = parsed_url.path

        # 获取请求体长度
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)

        try:
            payload = json.loads(post_data.decode('utf-8'))
        except Exception:
            self.send_error_response(400, "Invalid JSON body")
            return

        # ── 3. 上传云存档 ──
        if path == "/cloud_save/upload":
            username = payload.get("username", "")
            save_data = payload.get("save_data", {})

            if not username or not save_data:
                self.send_error_response(400, "Missing username or save_data")
                return

            safe_name = "".join([c for c in username if c.isalpha() or c.isdigit() or c=='_']).rstrip()
            if not safe_name:
                safe_name = "default"
            save_path = os.path.join(SAVES_DIR, f"{safe_name}.json")

            try:
                with open(save_path, "w", encoding="utf-8") as f:
                    json.dump(save_data, f, ensure_ascii=False, indent=4)
                
                self.send_json_response(200, {"status": "success", "message": "Saved successfully"})
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 4. 上报成绩到排行榜 ──
        elif path == "/leaderboard/submit":
            username = payload.get("username", "")
            intellect = payload.get("intellect", 10)
            school = payload.get("school", "西湖中学")

            if not username:
                self.send_error_response(400, "Missing username")
                return

            # ── 服务端校验：防止本地改档提交异常数值 ──
            try:
                intellect = int(intellect)
            except (ValueError, TypeError):
                self.send_error_response(400, "Invalid intellect value")
                return

            # 属性上限校验（游戏内 intellect 最大值为 100，与种子数据共用同一常量）
            if intellect < INTELLECT_MIN or intellect > INTELLECT_MAX:
                self.send_error_response(
                    400, f"intellect out of range [{INTELLECT_MIN}, {INTELLECT_MAX}]")
                return

            # 字段长度限制
            if len(username) > 20 or len(school) > 30:
                self.send_error_response(400, "username or school too long")
                return

            try:
                with open(LEADERBOARD_FILE, "r", encoding="utf-8") as f:
                    scores = json.load(f)
                
                # 如果用户已在榜上，更新为最高值，否则追加
                existing = None
                for s in scores:
                    if s.get("username") == username:
                        existing = s
                        break
                
                if existing:
                    existing["intellect"] = max(existing["intellect"], intellect)
                    existing["school"] = school
                else:
                    scores.append({
                        "username": username,
                        "intellect": intellect,
                        "school": school
                    })

                with open(LEADERBOARD_FILE, "w", encoding="utf-8") as f:
                    json.dump(scores, f, ensure_ascii=False, indent=4)

                self.send_json_response(200, {"status": "success", "message": "Score submitted"})
            except Exception as e:
                self.send_error_response(500, str(e))
        # ── 5. 提交新许愿 ──
        elif path == "/wishes/submit":
            username = payload.get("username", "")
            school = payload.get("school", "西湖中学")
            content = payload.get("content", "")

            if not username or not content:
                self.send_error_response(400, "Missing username or content")
                return

            try:
                with open(WISHES_FILE, "r", encoding="utf-8") as f:
                    wishes = json.load(f)

                wish_id = "wish_" + str(int(time.time() * 1000))

                # ── 虚拟留言机机制 (彩蛋) ──
                # 玩家自己发布的心愿（名字非预设 NPC）会混入 1-2 条角色打气留言。
                # M4：留言池与 NPC 名单来自 mock_seed_data.json，代码内不写死。
                replies = []
                if username not in SEED.get("npc_usernames", []):
                    virtual_pool = SEED.get("virtual_replies", [])
                    if virtual_pool:
                        chosen_count = min(random.randint(1, 2), len(virtual_pool))
                        replies = random.sample(virtual_pool, chosen_count)

                wishes.append({
                    "id": wish_id,
                    "username": username,
                    "school": school,
                    "content": content,
                    "replies": replies
                })

                with open(WISHES_FILE, "w", encoding="utf-8") as f:
                    json.dump(wishes, f, ensure_ascii=False, indent=4)

                self.send_json_response(200, {"status": "success", "message": "Wish submitted"})
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 6. 给别人的花灯留言 ──
        elif path == "/wishes/reply":
            wish_id = payload.get("wish_id", "")
            username = payload.get("username", "")
            school = payload.get("school", "西湖中学")
            content = payload.get("content", "")

            if not wish_id or not username or not content:
                self.send_error_response(400, "Missing wish_id, username or content")
                return

            try:
                with open(WISHES_FILE, "r", encoding="utf-8") as f:
                    wishes = json.load(f)
                
                found = False
                for w in wishes:
                    if w.get("id") == wish_id:
                        if "replies" not in w:
                            w["replies"] = []
                        w["replies"].append({
                            "username": username,
                            "school": school,
                            "content": content
                        })
                        found = True
                        break
                
                if found:
                    with open(WISHES_FILE, "w", encoding="utf-8") as f:
                        json.dump(wishes, f, ensure_ascii=False, indent=4)
                    self.send_json_response(200, {"status": "success", "message": "Comment submitted"})
                else:
                    self.send_error_response(404, "Wish not found")
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 7. 发送世界聊天消息 ──
        elif path == "/chat/send":
            username = payload.get("username", "")
            title = payload.get("title", "")
            school = payload.get("school", "西湖中学")
            content = payload.get("content", "")

            if not username or not content:
                self.send_error_response(400, "Missing username or content")
                return

            try:
                with open(CHAT_FILE, "r", encoding="utf-8") as f:
                    messages = json.load(f)
                
                msg_id = "msg_" + str(int(time.time() * 1000))
                messages.append({
                    "id": msg_id,
                    "username": username,
                    "title": title,
                    "school": school,
                    "content": content,
                    "timestamp": int(time.time())
                })
                
                # 保留最新 50 条
                messages = messages[-50:]
                
                with open(CHAT_FILE, "w", encoding="utf-8") as f:
                    json.dump(messages, f, ensure_ascii=False, indent=4)
                
                self.send_json_response(200, {"status": "success", "message": "Message sent"})
            except Exception as e:
                self.send_error_response(500, str(e))

        # ── 8. 更新/保存玩家全局档案 ──
        elif path == "/player/profile":
            username = payload.get("username", "")
            profile_data = payload.get("profile", {})

            if not username or not profile_data:
                self.send_error_response(400, "Missing username or profile")
                return

            safe_name = "".join([c for c in username if c.isalpha() or c.isdigit() or c=='_']).rstrip()
            if not safe_name:
                safe_name = "default"
            profile_path = os.path.join(PROFILES_DIR, f"{safe_name}.json")

            try:
                # 读取已有数据（如存在），做合并式更新，防止覆盖丢字段
                existing = {}
                if os.path.exists(profile_path):
                    with open(profile_path, "r", encoding="utf-8") as f:
                        existing = json.load(f)

                # 合并：列表字段去重合并，数值字段取新值
                for key in ["unlocked_titles", "unlocked_recipes", "seen_endings", "gallery_flags"]:
                    old_list = existing.get(key, [])
                    new_list = profile_data.get(key, [])
                    existing[key] = list(set(old_list) | set(new_list))

                existing["username"]        = username
                existing["ng_count"]        = profile_data.get("ng_count", existing.get("ng_count", 0))
                existing["inherited_money"] = profile_data.get("inherited_money", existing.get("inherited_money", 0))
                existing["updated_at"]      = time.strftime("%Y-%m-%dT%H:%M:%S")
                if not existing.get("created_at"):
                    existing["created_at"] = existing["updated_at"]

                with open(profile_path, "w", encoding="utf-8") as f:
                    json.dump(existing, f, ensure_ascii=False, indent=4)

                self.send_json_response(200, {"status": "success", "profile": existing})
            except Exception as e:
                self.send_error_response(500, str(e))

        else:
            self.send_error_response(404, "Endpoint not found")

    def send_error_response(self, code, message):
        self.send_json_response(code, {"status": "error", "message": message})

def resolve_port(cli_port=None):
    """M1：端口解析优先级 —— 命令行 > 环境变量 > 默认值。"""
    if cli_port is not None:
        return cli_port
    env_value = os.environ.get(ENV_PORT)
    if env_value:
        try:
            return int(env_value)
        except ValueError:
            print(f"[mock_server] 环境变量 {ENV_PORT}={env_value!r} 非法，回落默认端口")
    return DEFAULT_PORT


def main():
    parser = argparse.ArgumentParser(description="《西湖边的青春》本地联调 Mock Server")
    parser.add_argument("--port", type=int, default=None,
                        help=f"监听端口（默认 {DEFAULT_PORT}，也可用环境变量 {ENV_PORT}）")
    parser.add_argument("--host", default=DEFAULT_HOST,
                        help="监听地址（默认所有网卡；真机联调填本机内网 IP 亦可）")
    args = parser.parse_args()
    port = resolve_port(args.port)

    # 排行榜为空时填充种子数据，让游戏一开始看起来就有人在竞争（M2：已过 0-100 校验）
    with open(LEADERBOARD_FILE, "r", encoding="utf-8") as f:
        scores = json.load(f)
    if len(scores) == 0:
        _write_json(LEADERBOARD_FILE, _sanitized_leaderboard_seed())

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer((args.host, port), MockServerHandler) as httpd:
        print(f"Mock server running on port {port}  (db={DB_DIR})")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[mock_server] 已停止")


if __name__ == "__main__":
    main()
