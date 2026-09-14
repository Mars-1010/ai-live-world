from fastapi.testclient import TestClient

from backend.main import create_app


def test_panel_and_assets_are_served_from_the_backend_origin():
    with TestClient(create_app()) as client:
        response = client.get("/control-panel/")
        assert response.status_code == 200
        assert "text/html" in response.headers["content-type"]
        assert 'id="comment-form"' in response.text
        for asset in ["app.mjs", "client.mjs", "style.css"]:
            assert client.get(f"/control-panel/{asset}").status_code == 200
        assert client.get("/state").status_code == 200
        assert client.post("/event/gift", json={"tier": "small"}).status_code == 200


def test_static_directory_does_not_depend_on_working_directory(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    with TestClient(create_app()) as client:
        assert client.get("/control-panel/").status_code == 200


def test_static_mount_does_not_expose_backend_files_or_enable_cross_origin_access():
    with TestClient(create_app()) as client:
        assert client.get("/control-panel/%2e%2e/backend/main.py").status_code == 404
        assert client.get("/control-panel/missing.js").status_code == 404
        response = client.get("/state", headers={"Origin": "https://example.com"})
        assert "access-control-allow-origin" not in response.headers
