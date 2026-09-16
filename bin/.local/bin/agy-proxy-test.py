import http.server
import json
import subprocess
import time
import sys

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/v1/chat/completions':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            req = json.loads(post_data.decode('utf-8'))
            
            messages = req.get('messages', [])
            prompt = ""
            for m in messages:
                role = m.get('role', '')
                content = m.get('content', '')
                prompt += f"{role.upper()}: {content}\n"
            
            is_stream = req.get('stream', False)
            
            self.send_response(200)
            
            try:
                process = subprocess.Popen(
                    ["agy", "--dangerously-skip-permissions", "-p", prompt],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1
                )
                
                if is_stream:
                    self.send_header('Content-type', 'text/event-stream')
                    self.send_header('Cache-Control', 'no-cache')
                    self.send_header('Connection', 'keep-alive')
                    self.end_headers()
                    
                    for line in iter(process.stdout.readline, ''):
                        if not line:
                            break
                        chunk = {
                            "id": "chatcmpl-agy",
                            "object": "chat.completion.chunk",
                            "created": int(time.time()),
                            "model": "antigravity-cli",
                            "choices": [{
                                "index": 0,
                                "delta": {"role": "assistant", "content": line},
                                "finish_reason": None
                            }]
                        }
                        self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode('utf-8'))
                        self.wfile.flush()
                        
                    process.stdout.close()
                    process.wait()
                    
                    finish_chunk = {
                        "id": "chatcmpl-agy",
                        "object": "chat.completion.chunk",
                        "created": int(time.time()),
                        "model": "antigravity-cli",
                        "choices": [{
                            "index": 0,
                            "delta": {},
                            "finish_reason": "stop"
                        }]
                    }
                    self.wfile.write(f"data: {json.dumps(finish_chunk)}\n\n".encode('utf-8'))
                    self.wfile.write(b"data: [DONE]\n\n")
                    self.wfile.flush()
                else:
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    output = process.stdout.read()
                    process.wait()
                    response = {
                        "id": "chatcmpl-agy",
                        "object": "chat.completion",
                        "created": int(time.time()),
                        "model": "antigravity-cli",
                        "choices": [{
                            "index": 0,
                            "message": {
                                "role": "assistant",
                                "content": output
                            },
                            "finish_reason": "stop"
                        }]
                    }
                    self.wfile.write(json.dumps(response).encode('utf-8'))
                    
            except Exception as e:
                # If streaming, we might have already sent headers, but try to print it
                err_msg = f"\nError calling agy: {e}"
                if is_stream:
                    chunk = {
                        "id": "chatcmpl-agy",
                        "object": "chat.completion.chunk",
                        "created": int(time.time()),
                        "choices": [{"index": 0, "delta": {"content": err_msg}}]
                    }
                    try:
                        self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode('utf-8'))
                        self.wfile.write(b"data: [DONE]\n\n")
                        self.wfile.flush()
                    except:
                        pass

        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = http.server.HTTPServer(('127.0.0.1', 11435), ProxyHandler)
    print("agy proxy listening on port 11435")
    server.serve_forever()
