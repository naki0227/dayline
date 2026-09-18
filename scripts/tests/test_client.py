from unittest import TestCase
from unittest.mock import Mock, patch

from app_store_connect.client import Client


class AppStoreClientTests(TestCase):
    def test_http_failure_does_not_include_response_body(self) -> None:
        client = Client.__new__(Client)
        client.config = Mock()
        client.session = Mock()
        client.session.headers = {}
        client.session.request.return_value = Mock(
            ok=False,
            status_code=403,
            text="private account detail",
        )

        with (
            patch("app_store_connect.client.create_token", return_value="token"),
            self.assertRaisesRegex(RuntimeError, "HTTP 403") as error,
        ):
            client.get("/v1/apps")

        self.assertNotIn("private account detail", str(error.exception))

    def test_refreshes_short_lived_token_for_each_request(self) -> None:
        client = Client.__new__(Client)
        client.config = Mock()
        client.session = Mock()
        client.session.headers = {}
        client.session.request.return_value = Mock(ok=True, content=b"{}", json=dict)

        with patch(
            "app_store_connect.client.create_token", side_effect=["first", "second"]
        ) as tokens:
            client.get("/v1/apps")
            client.get("/v1/builds")

        self.assertEqual(tokens.call_count, 2)
        self.assertEqual(client.session.headers["Authorization"], "Bearer second")
