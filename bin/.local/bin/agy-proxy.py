#!/usr/bin/env python3
import http.server
import json
import subprocess
import time
import sys
import re

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
            
            tools = req.get('tools', [])
            if tools:
                prompt += "\n\nSYSTEM: You are the brain of an agent. You have access to these external tools:\n"
                prompt += json.dumps(tools, indent=2) + "\n"
                prompt += "To use a tool, you MUST output EXACTLY this format and nothing else:\n"
                prompt += "<TOOL_CALL>\n{\"name\": \"tool_name\", \"arguments\": {\"arg\": \"val\"}}\n</TOOL_CALL>\n"
                prompt += "DO NOT use your own built-in tools. ONLY use the external tools provided above if needed. If no tools are needed, answer normally.\n"
            
            is_stream = req.get('stream', False)
            self.send_response(200)
            
            try:
                # We use regular text output for agy to let it generate the tool call block
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
                    
                    # We will read everything into a buffer because tool calls need to be parsed
                    full_output = process.stdout.read()
                    process.wait()
                    
                    # Check for tool call
                    tool_match = re.search(r'<TOOL_CALL>\s*(\{.*?\})\s*</TOOL_CALL>', full_output, re.DOTALL)
                    
                    if tool_match:
                        try:
                            tool_data = json.loads(tool_match.group(1))
                            tool_name = tool_data.get("name")
                            tool_args = json.dumps(tool_data.get("arguments", {}))
                            
                            chunk = {
                                "id": "chatcmpl-agy",
                                "object": "chat.completion.chunk",
                                "created": int(time.time()),
                                "model": "antigravity-cli",
                                "choices": [{
                                    "index": 0,
                                    "delta": {
                                        "role": "assistant",
                                        "content": None,
                                        "tool_calls": [{
                                            "index": 0,
                                            "id": "call_" + str(int(time.time())),
                                            "type": "function",
                                            "function": {
                                                "name": tool_name,
                                                "arguments": tool_args
                                            }
                                        }]
                                    },
                                    "finish_reason": "tool_calls"
                                }]
                            }
                            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode('utf-8'))
                        except json.JSONDecodeError:
                            # fallback to text
                            chunk = {
                                "id": "chatcmpl-agy",
                                "object": "chat.completion.chunk",
                                "created": int(time.time()),
                                "model": "antigravity-cli",
                                "choices": [{"index": 0, "delta": {"role": "assistant", "content": full_output}, "finish_reason": None}]
                            }
                            self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode('utf-8'))
                    else:
                        # stream as one block for simplicity since agy -p doesn't stream easily with the tool logic
                        chunk = {
                            "id": "chatcmpl-agy",
                            "object": "chat.completion.chunk",
                            "created": int(time.time()),
                            "model": "antigravity-cli",
                            "choices": [{"index": 0, "delta": {"role": "assistant", "content": full_output}, "finish_reason": None}]
                        }
                        self.wfile.write(f"data: {json.dumps(chunk)}\n\n".encode('utf-8'))
                    
                    finish_chunk = {
                        "id": "chatcmpl-agy",
                        "object": "chat.completion.chunk",
                        "created": int(time.time()),
                        "model": "antigravity-cli",
                        "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]
                    }
                    self.wfile.write(f"data: {json.dumps(finish_chunk)}\n\n".encode('utf-8'))
                    self.wfile.write(b"data: [DONE]\n\n")
                    self.wfile.flush()
                else:
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    full_output = process.stdout.read()
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
                                "content": full_output
                            },
                            "finish_reason": "stop"
                        }]
                    }
                    
                    tool_match = re.search(r'<TOOL_CALL>\s*(\{.*?\})\s*</TOOL_CALL>', full_output, re.DOTALL)
                    if tool_match:
                        try:
                            tool_data = json.loads(tool_match.group(1))
                            response["choices"][0]["message"]["content"] = None
                            response["choices"][0]["message"]["tool_calls"] = [{
                                "id": "call_" + str(int(time.time())),
                                "type": "function",
                                "function": {
                                    "name": tool_data.get("name"),
                                    "arguments": json.dumps(tool_data.get("arguments", {}))
                                }
                            }]
                            response["choices"][0]["finish_reason"] = "tool_calls"
                        except json.JSONDecodeError:
                            pass
                            
                    self.wfile.write(json.dumps(response).encode('utf-8'))
                    
            except Exception as e:
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
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 11434), ProxyHandler)
    print("agy proxy listening on port 11434")
    server.serve_forever()
