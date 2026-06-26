#!/usr/bin/env python3
"""
Simple Flask application for Task 1
"""
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route('/', methods=['GET'])
def home():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'task1-app',
        'version': '1.0.0',
        'environment': os.getenv('ENV', 'development')
    }), 200

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok'}), 200

@app.route('/api/info', methods=['GET'])
def info():
    """API info endpoint"""
    return jsonify({
        'name': 'Task 1 App',
        'version': '1.0.0',
        'description': 'Jenkins Lab Task 1 Application'
    }), 200

if __name__ == '__main__':
    # Run on all interfaces, port 5000
    app.run(host='0.0.0.0', port=5000, debug=False)
