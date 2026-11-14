import 'package:googleapis_auth/auth_io.dart';

class GetServerKey {
  Future<String> getServerKeyToken() async {
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];

    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson({
        "type": "service_account",
        "project_id": "hoorain-ae51a",
        "private_key_id": "fd894acdeb871d71b5caf436a9801fab57334a5d",
        "private_key":
            "-----BEGIN PRIVATE KEY-----\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQDl66p+5g+/7uyA\nDHrBNk9VlVMBPk66gUkXopF3hG3d9C/PMI1Kfe+8d4wbDIubcs8wv0r+PK7kXYTG\nkknzm6c1FjAbKkIDGkoRDTcpJakdp5wVpjKVaU9EKhefRlXHgocXg2cQRejC4nkM\nDEqgjgR0U+0mWc85tq9nYNIa6N/jCzI+s2EpFPn7NjLVtPBneMwkAseeXv6IHIw8\nLx+NJlDlK7cmg9KAesgaFpIUVRfiME4dE3z9nHn5xHBSKA926+kRcj0ljVLV8u71\nKhEp7P7VqwJXhLzvzap/PUAGgEKAZ43rOVPdyYz1FrkGF0af7DODIGCH2ndjjEAr\nmSQRzZJdAgMBAAECggEAAmwluzmMT+7iAgVfo7qBQnsUyU4RQUjMbtnRI4u7JpwE\nhu/RhUfnZzpxOPW8YNJoWXCihyQ3iYNsuzTeX5kzvUzzC845rNOxlRVpD99sNTpH\nXDkIjmdyJNs2rYBttfDroHVLeDHsXmVJdjWI8cEdTeZ2eLF4i/ifR30PKaZreXZn\nH9k+laQkeBnZjaJk1jWhyytbsdco8c9NKpxWpx5A+j+aRRxkgoPIsO4QZsWci1D1\nd7zNHH6JKaGnIZG5qjLgLHAZeKtjzxeCP4Jfb9FalatvwvFc+En5BJRoGGwIcGpc\nylpfzE1cI8aoMLYTlrUneIjAO3FroYyBSgFqHLX20QKBgQDzQdCLfIVWwOXCVXlj\nU0rLK4EsHXxCPJBd43KMyuoAwH/cperZdO1GwuG6fWVXCB+2QIq5oPLEGLFwVvMB\ngPMohQ7HNVHrfxpNoICIGU0aJdqmMwJLWC3MNpHd59IB7jwOT54OIGQa3/B7Zzju\ngbg2Uu1mWy9FPJuLBI2dzfjRqQKBgQDx9wC0WW4LUS6k96HjPSigdw9IYft4RkQU\nbU+pY+pXviFfhVtiXwwJ4ZXazT75ycA4sT4dKITDWXMcckUYXrE+20GSM2NzxBkz\nBvI4ulGESL0bTosA1ENA4gA4Go4MgBOxw5YGpcubjkXztKTEdK6jxMk3RpB5iDXp\nbHwAkIwTlQKBgHKZsAD20e6UA+ow0HY9uD/NKBa7cV3XIIBK9h1kPyfJiLNPqzt1\nPY+XojZ0evisiBwZfgGD1LsTkwyEugkcUfHl9ZdeBFD42VB26/ayTMOjz8V6xHrw\neOr7Tm8HlsV4Ee0AD0tCcUbD94x7jbO3gyx8lwEgtj1dFz5AD+OnNLC5AoGAHjkW\nE3DgN/Wp990ekX3AJ1r3w7jJalqMgmis/KGIUfFjxcSoh38Lx+gviab9aMH0iqBI\n++dlvejcYf879jFNvmYwqIxWrc0ewKrrcn6DVByp0lFbN31L8TzJfjiC6bjNvPSL\nNsVay1FYF3rG4esZLUeVQpxDy4piAYgVbRShCokCgYBOhWxuL7KgCXZshulZTdrc\nlgw1oPg1ffhLqW8aV2mVnWwK2MkeXksrK4b5A5qc5Vdv+YVQg64CXm0/ajCCVJbD\nzcN4MsUIOtEo6FH8jIU/HuBTKV+EfHrrz2eAYc9c7t8vtdoYUmmej7JO6LwQd2rO\n4JF3aLSWLMvZy/BbXz0tzA==\n-----END PRIVATE KEY-----\n",
        "client_email":
            "firebase-adminsdk-fbsvc@hoorain-ae51a.iam.gserviceaccount.com",
        "client_id": "101467690441373191651",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40hoorain-ae51a.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com",
      }),
      scopes,
    );
    final accessServerKey = client.credentials.accessToken.data;
    return accessServerKey;
  }
}
