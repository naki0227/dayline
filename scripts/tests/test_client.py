from unittest import TestCase
from unittest.mock import Mock

from app_store_connect.client import Client


class AppStoreClientTests(TestCase):
    def test_http_failure_does_not_include_response_body(self) -> None:
        client = Client.__new__(Client)
        client.session = Mock()
        client.session.request.return_value = Mock(
            ok=False,
            status_code=403,
            text="private account detail",
        )

        with self.assertRaisesRegex(RuntimeError, "HTTP 403") as error:
            client.get("/v1/apps")

        self.assertNotIn("private account detail", str(error.exception))
