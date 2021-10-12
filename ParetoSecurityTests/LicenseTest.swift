//
//  LicenseTest.swift
//  LicenseTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import XCTest

private let publicKey = """
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv
vkTtwlvBsaJq7S5wA+kzeVOVpVWwkWdVha4s38XM/pa/yr47av7+z3VTmvDRyAHc
aT92whREFpLv9cj5lTeJSibyr/Mrm/YtjCZVWgaOYIhwrXwKLqPr/11inWsAkfIy
tvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0
e+lf4s4OxQawWD79J9/5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb
V6L11BWkpzGXSW4Hv43qa+GSYOD2QU68Mb59oSk2OB+BtOLpJofmbGEGgvmwyCI9
MwIDAQAB
"""

class LicenseTest: XCTestCase {
    override class func setUp() {
        super.setUp()
        UserDefaults.standard.removeAll()
        UserDefaults.standard.synchronize()
    }

    func testPersonaLicense() throws {
        // https://jwt.io/#debugger-io?token=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwZXJzb25hbEBkb21haW4uY29tIiwicm9sZSI6InNpbmdsZSIsInV1aWQiOiIxMjM0IiwiaWF0IjoxNTE2MjM5MDIyfQ.Cc9S3KmJKeb6moIVxv-f_wOAqVZ2Hz3hnFtyDkj2uspScFvFY8mI6OkK83f8Zy7Wr_str5_lHDu3MwuHZJFnPn5D6vZYswzGRXk--9ulMq77c8lylYROZZjyEUU4GiBqTQrn8I6T9cBElvlZdKo6jOTvTKHV6hQFl2cUFd9Vi_6E_JJGHm1BEDZKhB5DHcwJATx1h4WE4sEXTq0kEHo_y2RcPM9LBkxOynrIqiTkF_0lv8HzW5fi431zdspvbmBpbh8hhMDxs3JNKXVE83DvYLU-uCvRysm5YJ46Gyiiu96rG-pH-HVLYSVFuepTCQLbWmfmL4PE53Lj0ZSzFY6W1A&publicKey=-----BEGIN%20PUBLIC%20KEY-----%0AMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv%0AvkTtwlvBsaJq7S5wA%2BkzeVOVpVWwkWdVha4s38XM%2Fpa%2Fyr47av7%2Bz3VTmvDRyAHc%0AaT92whREFpLv9cj5lTeJSibyr%2FMrm%2FYtjCZVWgaOYIhwrXwKLqPr%2F11inWsAkfIy%0AtvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0%0Ae%2Blf4s4OxQawWD79J9%2F5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb%0AV6L11BWkpzGXSW4Hv43qa%2BGSYOD2QU68Mb59oSk2OB%2BBtOLpJofmbGEGgvmwyCI9%0AMwIDAQAB%0A-----END%20PUBLIC%20KEY-----
        let data = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwZXJzb25hbEBkb21haW4uY29tIiwicm9sZSI6InNpbmdsZSIsInV1aWQiOiIxMjM0IiwiaWF0IjoxNTE2MjM5MDIyfQ.Cc9S3KmJKeb6moIVxv-f_wOAqVZ2Hz3hnFtyDkj2uspScFvFY8mI6OkK83f8Zy7Wr_str5_lHDu3MwuHZJFnPn5D6vZYswzGRXk--9ulMq77c8lylYROZZjyEUU4GiBqTQrn8I6T9cBElvlZdKo6jOTvTKHV6hQFl2cUFd9Vi_6E_JJGHm1BEDZKhB5DHcwJATx1h4WE4sEXTq0kEHo_y2RcPM9LBkxOynrIqiTkF_0lv8HzW5fi431zdspvbmBpbh8hhMDxs3JNKXVE83DvYLU-uCvRysm5YJ46Gyiiu96rG-pH-HVLYSVFuepTCQLbWmfmL4PE53Lj0ZSzFY6W1A"
        XCTAssertNoThrow(try VerifyLicense(withLicense: data, publicKey: publicKey))
    }

    func testTeamTicket() throws {
        // https://jwt.io/#debugger-io?token=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZWFtQGRvbWFpbi5jb20iLCJyb2xlIjoidGVhbSIsInRlYW1JRCI6IjEyMzQiLCJ0ZWFtTmFtZSI6InRlYW1OYW1lIiwiZGV2aWNlSUQiOiI0NTY3IiwiaWF0IjoxNTE2MjM5MDIyfQ.VvKXwoTjWh127lYfPnHuEGGy3RpuvYvdGd0I-0XANiXaGSoDOXpaqM-Xs_UBcgylAEP3GArD65FLbXs2fJIlWRlYNuZ-iNHzDIdsLNqrqAA1BUx3naft8AATCmstuCOMtkNyi3-ZjNuq0ffafTIQqc1pGwfY5kkTYcVRlDDadV29iuK8Pl2NJl-WfoYkXHyqKoa0a1KyjTmwE1cyxdwcsrfHaZ3cujtrjpzO0uSyM-hBCFSul7okGlFwSjHP3Os0Onb3tflIAt4fPWB7K6LLhGF5FkgM0Aa7oNgi_T4nChmpCIb96sDJoKoXpAND312ZCCw8xSmn7LQnduC6tJBEuA&publicKey=-----BEGIN%20PUBLIC%20KEY-----%0AMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv%0AvkTtwlvBsaJq7S5wA%2BkzeVOVpVWwkWdVha4s38XM%2Fpa%2Fyr47av7%2Bz3VTmvDRyAHc%0AaT92whREFpLv9cj5lTeJSibyr%2FMrm%2FYtjCZVWgaOYIhwrXwKLqPr%2F11inWsAkfIy%0AtvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0%0Ae%2Blf4s4OxQawWD79J9%2F5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb%0AV6L11BWkpzGXSW4Hv43qa%2BGSYOD2QU68Mb59oSk2OB%2BBtOLpJofmbGEGgvmwyCI9%0AMwIDAQAB%0A-----END%20PUBLIC%20KEY-----
        let data = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZWFtQGRvbWFpbi5jb20iLCJyb2xlIjoidGVhbSIsInRlYW1JRCI6IjEyMzQiLCJ0ZWFtTmFtZSI6InRlYW1OYW1lIiwiZGV2aWNlSUQiOiI0NTY3IiwiaWF0IjoxNTE2MjM5MDIyfQ.VvKXwoTjWh127lYfPnHuEGGy3RpuvYvdGd0I-0XANiXaGSoDOXpaqM-Xs_UBcgylAEP3GArD65FLbXs2fJIlWRlYNuZ-iNHzDIdsLNqrqAA1BUx3naft8AATCmstuCOMtkNyi3-ZjNuq0ffafTIQqc1pGwfY5kkTYcVRlDDadV29iuK8Pl2NJl-WfoYkXHyqKoa0a1KyjTmwE1cyxdwcsrfHaZ3cujtrjpzO0uSyM-hBCFSul7okGlFwSjHP3Os0Onb3tflIAt4fPWB7K6LLhGF5FkgM0Aa7oNgi_T4nChmpCIb96sDJoKoXpAND312ZCCw8xSmn7LQnduC6tJBEuA"
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
