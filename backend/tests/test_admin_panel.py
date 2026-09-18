"""The admin panel web UI (Point 5): access control, pages, filters, actions."""
import pytest

from app import db
from app.models.chat import Chat, ChatMember
from app.models.message import Message
from app.models.support import SecurityAlert, SupportTicket
from app.models.user import User, UserDevice, UserSession

SECRET = 'sm-admin-x9k2p7'


@pytest.fixture()
def panel(app, client, monkeypatch):
    """A logged-in panel session."""
    monkeypatch.setenv('ADMIN_USERNAME', 'superadmin')
    monkeypatch.setenv('ADMIN_PASSWORD', 'panel-test-password')
    response = client.post(f'/{SECRET}/login', data={
        'username': 'superadmin', 'password': 'panel-test-password'})
    assert response.status_code == 302
    return client


def csrf(client):
    """Read the CSRF token the panel put in the session."""
    with client.session_transaction() as session:
        return session['admin_csrf']


def text(response):
    return response.get_data(as_text=True)


# ------------------------------------------------------------ access control
def test_the_panel_is_hidden_behind_its_secret_path(client):
    assert client.get('/wrong-secret/').status_code == 404
    assert client.get('/wrong-secret/login').status_code == 404
    assert client.get('/wrong-secret/users').status_code == 404


def test_pages_redirect_to_login_when_signed_out(client):
    for path in ('', 'users', 'chats', 'messages', 'support', 'audit',
                 'reports', 'media', 'devices', 'security'):
        response = client.get(f'/{SECRET}/{path}')
        assert response.status_code == 302
        assert 'login' in response.headers['Location']


def test_wrong_credentials_are_rejected(client, monkeypatch):
    monkeypatch.setenv('ADMIN_USERNAME', 'superadmin')
    monkeypatch.setenv('ADMIN_PASSWORD', 'panel-test-password')
    response = client.post(f'/{SECRET}/login', data={
        'username': 'superadmin', 'password': 'wrong'})
    assert response.status_code == 200
    assert 'اشتباه' in text(response)


def test_unset_credentials_never_authenticate(client, monkeypatch):
    """A deployment that forgot to set ADMIN_PASSWORD must not be wide open."""
    monkeypatch.delenv('ADMIN_USERNAME', raising=False)
    monkeypatch.delenv('ADMIN_PASSWORD', raising=False)
    response = client.post(f'/{SECRET}/login',
                           data={'username': '', 'password': ''})
    assert response.status_code == 200
    with client.session_transaction() as session:
        assert not session.get('admin_logged_in')


def test_repeated_failures_are_throttled(client, monkeypatch):
    monkeypatch.setenv('ADMIN_USERNAME', 'superadmin')
    monkeypatch.setenv('ADMIN_PASSWORD', 'panel-test-password')
    from app.admin.routes import _login_attempts
    _login_attempts.clear()
    for _ in range(5):
        client.post(f'/{SECRET}/login',
                    data={'username': 'superadmin', 'password': 'nope'})
    blocked = client.post(f'/{SECRET}/login', data={
        'username': 'superadmin', 'password': 'panel-test-password'})
    assert 'بیش از حد' in text(blocked)
    _login_attempts.clear()


def test_logout_clears_the_session(panel, client):
    client.get(f'/{SECRET}/logout')
    assert client.get(f'/{SECRET}/users').status_code == 302


# ------------------------------------------------------------------- pages
def test_every_page_renders(panel, client, make_message, upload):
    make_message('m1')
    upload('bob')
    for path in ('', 'users', 'chats', 'messages', 'support',
                 'support?tab=tickets', 'reports', 'media', 'devices',
                 'security', 'audit'):
        response = client.get(f'/{SECRET}/{path}')
        assert response.status_code == 200, path
        assert 'SecureMessenger' in text(response)


def test_the_dashboard_shows_counters_and_navigation(panel, client):
    body = text(client.get(f'/{SECRET}/'))
    assert 'کاربران' in body
    assert 'پشتیبانی' in body
    assert 'رویدادهای امنیتی' in body
    # The 14-day chart is rendered, not a placeholder.
    assert 'class="chart"' in body


def test_user_and_chat_detail_pages_render(panel, client, make_message):
    make_message('m1', sender_id='bob')
    user_page = client.get(f'/{SECRET}/users/bob')
    assert user_page.status_code == 200
    assert 'Bob' in text(user_page)

    chat_page = client.get(f'/{SECRET}/chats/chat')
    assert chat_page.status_code == 200
    assert 'اعضا' in text(chat_page)


def test_missing_records_render_a_friendly_page_not_a_crash(panel, client):
    assert client.get(f'/{SECRET}/users/nope').status_code == 200
    assert 'یافت نشد' in text(client.get(f'/{SECRET}/users/nope'))
    assert client.get(f'/{SECRET}/chats/nope').status_code == 200


# ------------------------------------------------------------------ filters
def test_user_filters_actually_narrow_the_list(panel, client, app):
    with app.app_context():
        db.session.get(User, 'bob').is_active = False
        db.session.commit()
    banned = text(client.get(f'/{SECRET}/users?status=banned'))
    assert 'Bob' in banned
    assert 'Carol' not in banned

    searched = text(client.get(f'/{SECRET}/users?q=carol'))
    assert 'Carol' in searched
    assert 'Bob' not in searched


def test_message_filters_narrow_the_list(panel, client, make_message):
    make_message('m1', content='hello world', sender_id='alice')
    make_message('m2', content='different text', sender_id='bob')
    filtered = text(client.get(f'/{SECRET}/messages?q=hello'))
    assert 'hello world' in filtered
    assert 'different text' not in filtered


def test_chat_filters_narrow_the_list(panel, client, app):
    with app.app_context():
        db.session.add(Chat(id='grp', chat_type='group', title='Team Chat',
                            created_by='alice'))
        db.session.commit()
    groups = text(client.get(f'/{SECRET}/chats?chat_type=group'))
    assert 'Team Chat' in groups
    privates = text(client.get(f'/{SECRET}/chats?chat_type=private'))
    assert 'Team Chat' not in privates


def test_pagination_appears_and_preserves_filters(panel, client, app):
    with app.app_context():
        for index in range(60):
            db.session.add(User(
                id=f'bulk{index}', email=f'bulk{index}@example.test',
                username=f'bulk{index}', display_name=f'Bulk {index}',
                password_hash='x', totp_secret='JBSWY3DPEHPK3PXP'))
        db.session.commit()
    body = text(client.get(f'/{SECRET}/users?status=active'))
    assert 'class="pager"' in body
    # The next-page link keeps the active filter.
    assert 'status=active' in body and 'page=2' in body


def test_the_audit_filter_dropdown_is_built_from_real_actions(panel, client,
                                                              app):
    from app.models.audit import AuditLog
    with app.app_context():
        db.session.add(AuditLog(actor_id='alice', action='a_distinct_action',
                                entity_type='user', entity_id='alice'))
        db.session.commit()
    body = text(client.get(f'/{SECRET}/audit'))
    assert 'a_distinct_action' in body
    filtered = text(client.get(f'/{SECRET}/audit?action=a_distinct_action'))
    assert 'a_distinct_action' in filtered


# ------------------------------------------------------------------ actions
def test_mutating_actions_require_a_csrf_token(panel, client):
    response = client.post(f'/{SECRET}/users/bob/toggle', data={})
    assert response.status_code == 302
    with client.session_transaction() as session:
        assert session['admin_flash'][0] == 'err'


def test_toggling_a_user_blocks_them_and_kills_sessions(panel, client, app):
    with app.app_context():
        from datetime import datetime, timedelta
        db.session.add(UserSession(
            user_id='bob', refresh_token='rt', is_active=True,
            expires_at=datetime.utcnow() + timedelta(days=1)))
        db.session.commit()
    response = client.post(f'/{SECRET}/users/bob/toggle',
                           data={'csrf_token': csrf(client)})
    assert response.status_code == 302
    with app.app_context():
        assert db.session.get(User, 'bob').is_active is False
        assert UserSession.query.filter_by(
            user_id='bob', is_active=True).count() == 0


def test_limiting_and_unlimiting_a_user_works(panel, client, app):
    client.post(f'/{SECRET}/users/bob/limit',
                data={'csrf_token': csrf(client)})
    with app.app_context():
        assert db.session.get(User, 'bob').is_limited is True
    client.post(f'/{SECRET}/users/bob/limit',
                data={'csrf_token': csrf(client)})
    with app.app_context():
        assert db.session.get(User, 'bob').is_limited is False


def test_suspending_a_chat_works(panel, client, app):
    client.post(f'/{SECRET}/chats/chat/suspend',
                data={'csrf_token': csrf(client)})
    with app.app_context():
        assert db.session.get(Chat, 'chat').is_suspended is True


def test_deleting_a_message_marks_it_for_everyone(panel, client, app,
                                                  make_message):
    make_message('m1')
    client.post(f'/{SECRET}/messages/m1/delete',
                data={'csrf_token': csrf(client)})
    with app.app_context():
        assert db.session.get(Message, 'm1').is_deleted_for_all is True


# ------------------------------------------------------------------ support
def _support_thread(app):
    with app.app_context():
        db.session.add(User(
            id='agent', email='agent@example.test', username='agent',
            display_name='Agent', password_hash='x',
            totp_secret='JBSWY3DPEHPK3PXP', is_support=True))
        chat = Chat(id='sup', chat_type='support', title='پشتیبانی',
                    created_by='bob')
        db.session.add(chat)
        db.session.flush()
        db.session.add_all([
            ChatMember(chat_id='sup', user_id='bob'),
            ChatMember(chat_id='sup', user_id='agent', role='admin'),
        ])
        db.session.add(Message(chat_id='sup', sender_id='bob',
                               message_type='text',
                               content='کد برای من نمی‌آید'))
        db.session.commit()


def test_the_support_tab_lists_user_conversations(panel, client, app):
    _support_thread(app)
    body = text(client.get(f'/{SECRET}/support'))
    assert 'Bob' in body
    assert 'کد برای من نمی‌آید' in body


def test_an_admin_can_open_and_read_a_support_thread(panel, client, app):
    _support_thread(app)
    body = text(client.get(f'/{SECRET}/support/chat/sup'))
    assert 'کد برای من نمی‌آید' in body
    assert 'اطلاعات کاربر' in body


def test_an_admin_can_reply_in_a_support_thread(panel, client, app):
    _support_thread(app)
    response = client.post(f'/{SECRET}/support/chat/sup/reply', data={
        'csrf_token': csrf(client), 'content': 'بررسی شد، دوباره امتحان کنید'})
    assert response.status_code == 302
    with app.app_context():
        reply = Message.query.filter_by(chat_id='sup',
                                        sender_id='agent').first()
        assert reply is not None
        assert 'بررسی شد' in reply.content


def test_replying_without_a_support_account_explains_the_problem(panel, client,
                                                                 app):
    with app.app_context():
        chat = Chat(id='sup2', chat_type='support', created_by='bob')
        db.session.add(chat)
        db.session.flush()
        db.session.add(ChatMember(chat_id='sup2', user_id='bob'))
        db.session.commit()
    client.post(f'/{SECRET}/support/chat/sup2/reply',
                data={'csrf_token': csrf(client), 'content': 'سلام'})
    with client.session_transaction() as session:
        kind, message = session['admin_flash']
    assert kind == 'err'
    assert 'پشتیبان' in message


def test_login_screen_tickets_appear_in_the_panel(panel, client):
    client.post('/api/v1/support/tickets', json={
        'mobile_number': '09121234567', 'topic': 'code_not_received',
        'message': 'کد تأیید نمی‌آید'})
    body = text(client.get(f'/{SECRET}/support?tab=tickets'))
    assert 'کد تأیید نمی‌آید' in body
    assert '+989121234567' in body


def test_a_ticket_status_can_be_changed_from_the_panel(panel, client, app):
    client.post('/api/v1/support/tickets', json={
        'mobile_number': '09121234567', 'message': 'کمک'})
    with app.app_context():
        ticket_id = SupportTicket.query.first().id
    client.post(f'/{SECRET}/support/tickets/{ticket_id}/status',
                data={'csrf_token': csrf(client), 'status': 'resolved'})
    with app.app_context():
        assert db.session.get(SupportTicket, ticket_id).status == 'resolved'


def test_the_security_page_lists_alerts(panel, client, app):
    with app.app_context():
        db.session.add(SecurityAlert(
            user_id='bob', alert_type='new_device_login',
            title='ورود دستگاه جدید', severity='critical',
            device_name='Unknown Phone', ip_address='10.0.0.9'))
        db.session.commit()
    body = text(client.get(f'/{SECRET}/security?severity=critical'))
    assert 'ورود دستگاه جدید' in body
    assert 'Unknown Phone' in body


def test_the_devices_page_flags_the_primary_device(panel, client, app):
    with app.app_context():
        db.session.add(UserDevice(
            id='d1', user_id='bob', device_fingerprint='fp',
            device_name='Bob Phone', is_primary=True))
        db.session.commit()
    body = text(client.get(f'/{SECRET}/devices?primary=yes'))
    assert 'Bob Phone' in body
    assert 'اصلی' in body


def test_html_in_user_content_is_escaped_not_rendered(panel, client,
                                                      make_message):
    make_message('m1', content='<script>alert(1)</script>')
    body = text(client.get(f'/{SECRET}/messages'))
    assert '<script>alert(1)</script>' not in body
    assert '&lt;script&gt;' in body
