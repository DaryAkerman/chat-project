from flask import Flask, render_template, request, session, redirect, url_for
from flask_socketio import SocketIO, send
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import pytz

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your_secret_key'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///chat.db'
db = SQLAlchemy(app)
socketio = SocketIO(app)

# Database Models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    messages = db.relationship('Message', backref='user', lazy=True)

class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    content = db.Column(db.String(500), nullable=False)
    timestamp = db.Column(db.DateTime, nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)

# Routes
@app.route('/', methods=['GET', 'POST'])
def index():
    # Check if the user is already logged in
    if 'username' in session and 'user_id' in session:
        return redirect(url_for('chat'))
    
    if request.method == 'POST':
        username = request.form['username']
        
        # Check if username already exists
        existing_user = User.query.filter_by(username=username).first()
        if existing_user:
            # Log the user in by setting the session data
            session['username'] = existing_user.username
            session['user_id'] = existing_user.id
            return redirect(url_for('chat'))
        
        # Create new user and save to database
        new_user = User(username=username)
        db.session.add(new_user)
        db.session.commit()
        
        session['username'] = username
        session['user_id'] = new_user.id
        return redirect(url_for('chat'))
    
    return render_template('index.html')

@app.route('/chat')
def chat():
    # Redirect to the index if the user is not in session
    if 'username' not in session or 'user_id' not in session:
        return redirect(url_for('index'))
    
    username = session['username']
    return render_template('chat.html', username=username)

@socketio.on('message')
def handle_message(msg):
    username = session.get('username')
    user_id = session.get('user_id')
    
    if username and user_id:
        israel_time = datetime.now(pytz.timezone('Asia/Jerusalem'))
        
        # Save message to database
        new_message = Message(content=msg, timestamp=israel_time, user_id=user_id)
        db.session.add(new_message)
        db.session.commit()
        
        # Broadcast message to all clients
        send(f"<b>{username}</b>: {msg}", broadcast=True)

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    socketio.run(app, host="0.0.0.0", port=5000, debug=True, allow_unsafe_werkzeug=True)


