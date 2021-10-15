//
//  LicenseTest.swift
//  LicenseTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import XCTest

private let publicKey = """
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1SU1LfVLPHCozMxH2Mo
4lgOEePzNm0tRgeLezV6ffAt0gunVTLw7onLRnrq0/IzW7yWR7QkrmBL7jTKEn5u
+qKhbwKfBstIs+bMY2Zkp18gnTxKLxoS2tFczGkPLPgizskuemMghRniWaoLcyeh
kd3qqGElvW/VDL5AaWTg0nLVkjRo9z+40RQzuVaE8AkAFmxZzow3x+VJYKdjykkJ
0iT9wCS0DRTXu269V264Vf/3jvredZiKRkgwlL9xNAwxXFg0x/XFw005UWVRIkdg
cKWTjpBP2dPwVZ4WWC+9aGVd+Gyn1o0CLelf4rEjGoXbAAEgAqeGUxrcIlbjXfbc
mwIDAQAB
"""

class LicenseTest: XCTestCase {
    override class func setUp() {
        super.setUp()
        UserDefaults.standard.removeAll()
        UserDefaults.standard.synchronize()
    }

    func testPersonaLicense() throws {
        // https://jwt.io/#debugger-io?token=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwZXJzb25hbEBkb21haW4uY29tIiwicm9sZSI6InNpbmdsZSIsInV1aWQiOiIxMjM0IiwiaWF0IjoxNTE2MjM5MDIyfQ.Cc9S3KmJKeb6moIVxv-f_wOAqVZ2Hz3hnFtyDkj2uspScFvFY8mI6OkK83f8Zy7Wr_str5_lHDu3MwuHZJFnPn5D6vZYswzGRXk--9ulMq77c8lylYROZZjyEUU4GiBqTQrn8I6T9cBElvlZdKo6jOTvTKHV6hQFl2cUFd9Vi_6E_JJGHm1BEDZKhB5DHcwJATx1h4WE4sEXTq0kEHo_y2RcPM9LBkxOynrIqiTkF_0lv8HzW5fi431zdspvbmBpbh8hhMDxs3JNKXVE83DvYLU-uCvRysm5YJ46Gyiiu96rG-pH-HVLYSVFuepTCQLbWmfmL4PE53Lj0ZSzFY6W1A&publicKey=-----BEGIN%20PUBLIC%20KEY-----%0AMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv%0AvkTtwlvBsaJq7S5wA%2BkzeVOVpVWwkWdVha4s38XM%2Fpa%2Fyr47av7%2Bz3VTmvDRyAHc%0AaT92whREFpLv9cj5lTeJSibyr%2FMrm%2FYtjCZVWgaOYIhwrXwKLqPr%2F11inWsAkfIy%0AtvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0%0Ae%2Blf4s4OxQawWD79J9%2F5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb%0AV6L11BWkpzGXSW4Hv43qa%2BGSYOD2QU68Mb59oSk2OB%2BBtOLpJofmbGEGgvmwyCI9%0AMwIDAQAB%0A-----END%20PUBLIC%20KEY-----
        let data = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwZXJzb25hbEBkb21haW4uY29tIiwicm9sZSI6InNpbmdsZSIsInV1aWQiOiIxMjM0IiwiaWF0IjoxNTE2MjM5MDIyfQ.OBUH4J_qEd_ss7atFbZFirBCiWWJo7u7NuUCwY147F-lPyB-elbN2r6IIpuAPP_8zCZP7jz2Hd-F2WI2irWQ74mdv4QV3HO-giuBXqfab5QK3n0mTbS5NaNVI0ExXJjtkpCV0MZiKFhLjeYj60so93FZrOT5uOmHn48lJADVhSQ5CnlFp8atJbieyxudZc_B5xUaOa-0im8VVX3zcEUPD0w_2SuCKBuBlY7309QIk6Gex1G7olJfvlg6ErLs7ORw-r93GPNaex3HuEi0EJrm1dxS3XUd4Ufrjdmfz-tZGxhlh0gdN4hFAeufV3uvx8oOUjLbZ621NhGUnrydBnhDlA"
        XCTAssertNoThrow(try VerifyLicense(withLicense: data, publicKey: publicKey))
    }

    func testTeamTicket() throws {
        // https://jwt.io/#debugger-io?token=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZWFtQGRvbWFpbi5jb20iLCJyb2xlIjoidGVhbSIsInRlYW1JRCI6IjEyMzQiLCJ0ZWFtTmFtZSI6InRlYW1OYW1lIiwiZGV2aWNlSUQiOiI0NTY3IiwiaWF0IjoxNTE2MjM5MDIyfQ.VvKXwoTjWh127lYfPnHuEGGy3RpuvYvdGd0I-0XANiXaGSoDOXpaqM-Xs_UBcgylAEP3GArD65FLbXs2fJIlWRlYNuZ-iNHzDIdsLNqrqAA1BUx3naft8AATCmstuCOMtkNyi3-ZjNuq0ffafTIQqc1pGwfY5kkTYcVRlDDadV29iuK8Pl2NJl-WfoYkXHyqKoa0a1KyjTmwE1cyxdwcsrfHaZ3cujtrjpzO0uSyM-hBCFSul7okGlFwSjHP3Os0Onb3tflIAt4fPWB7K6LLhGF5FkgM0Aa7oNgi_T4nChmpCIb96sDJoKoXpAND312ZCCw8xSmn7LQnduC6tJBEuA&publicKey=-----BEGIN%20PUBLIC%20KEY-----%0AMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv%0AvkTtwlvBsaJq7S5wA%2BkzeVOVpVWwkWdVha4s38XM%2Fpa%2Fyr47av7%2Bz3VTmvDRyAHc%0AaT92whREFpLv9cj5lTeJSibyr%2FMrm%2FYtjCZVWgaOYIhwrXwKLqPr%2F11inWsAkfIy%0AtvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0%0Ae%2Blf4s4OxQawWD79J9%2F5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb%0AV6L11BWkpzGXSW4Hv43qa%2BGSYOD2QU68Mb59oSk2OB%2BBtOLpJofmbGEGgvmwyCI9%0AMwIDAQAB%0A-----END%20PUBLIC%20KEY-----
        let data = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJqdEBuaXRlby5jbyIsInRlYW1JRCI6IjI0MjljNDllLTM3YmItNDFiYi05MDc3LTZiYjYyMDJlMjU1YiIsInJvbGUiOiJ0ZWFtIiwiaWF0IjoxNjM0Mjk5NDI4LCJ0b2tlbiI6ImV5SjBlWEFpT2lKS1YxUWlMQ0poYkdjaU9pSklVelV4TWlKOS5leUp5YjJ4bGN5STZXeUpzYVc1clgyUmxkbWxqWlNJc0luVndaR0YwWlY5a1pYWnBZMlVpWFN3aWRHVmhiVjlwWkNJNklqSTBNamxqTkRsbExUTTNZbUl0TkRGaVlpMDVNRGMzTFRaaVlqWXlNREpsTWpVMVlpSXNJbk4xWWlJNkltcDBRRzVwZEdWdkxtTnZJaXdpYVdGMElqb3hOak0wTWprNU5ESTRmUS5LOHc0Sk5CYzFJN09fNzZ6MUxzR254REVjeUJwak96NzFac1FqTFVpWkpTMlJFUWt6RFVPeW1Zb2hRTk1LT0pBLU05RmM3aVFDWmhISkZjUmFjSng1QSJ9.sb8Q79nuIc0NQsiAye2VlLTZQJ5bxpE0r814Nla4zdPy8h_Iw026KXbx9WZo7qh9ZW9X7XXR7bEkk_T48cA7yjBS70amsEV1ZmgllOaHdhqFLqVhy4ny9IkvbqYqQa-pTHDrQ04wgFPr4EgE5Y2Ce6-8EfCGuJsN-OHZK-tmhgR1cJ7kiIundxDBdL-eZwLahx_jm495RBp08CgN0G7C7qIdr7BrM4N3Sz2UuuEoJK2SeAWEnNkD2XHk1617HjCv2lRfnjoKKNYZgemnE_uGBaSWAud2D90W8b5tqpbBV16dbzx_8Y9jVtmwmVfIOcB4RfMiPrcWbxVAUj9OBNvkCg"
        XCTAssertNoThrow(try VerifyTeamTicket(withTicket: data, publicKey: publicKey))
    }

    func testPersonaLicenseFail() throws {
        let data = ""
        XCTAssertThrowsError(try VerifyLicense(withLicense: data, publicKey: publicKey))
    }

    func testTeamTicketFail() throws {
        let data = ""
        XCTAssertThrowsError(try VerifyTeamTicket(withTicket: data, publicKey: publicKey))
    }
}
