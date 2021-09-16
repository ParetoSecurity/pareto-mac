//
//  LicenseTest.swift
//  LicenseTest
//
//  Created by Janez Troha on 20/09/2021.
//

@testable import Pareto_Security
import XCTest

private let publicKey = """
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv
vkTtwlvBsaJq7S5wA+kzeVOVpVWwkWdVha4s38XM/pa/yr47av7+z3VTmvDRyAHc
aT92whREFpLv9cj5lTeJSibyr/Mrm/YtjCZVWgaOYIhwrXwKLqPr/11inWsAkfIy
tvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0
e+lf4s4OxQawWD79J9/5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb
V6L11BWkpzGXSW4Hv43qa+GSYOD2QU68Mb59oSk2OB+BtOLpJofmbGEGgvmwyCI9
MwIDAQAB
-----END PUBLIC KEY-----
"""

class LicenseTest: XCTestCase {
    func testPersonaLicense() throws {
        // https://jwt.io/#debugger-io?token=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwZXJzb25hbEBkb21haW4uY29tIiwicm9sZSI6InNpbmdsZSIsInV1aWQiOiIxMjM0IiwiaWF0IjoxNTE2MjM5MDIyfQ.Cc9S3KmJKeb6moIVxv-f_wOAqVZ2Hz3hnFtyDkj2uspScFvFY8mI6OkK83f8Zy7Wr_str5_lHDu3MwuHZJFnPn5D6vZYswzGRXk--9ulMq77c8lylYROZZjyEUU4GiBqTQrn8I6T9cBElvlZdKo6jOTvTKHV6hQFl2cUFd9Vi_6E_JJGHm1BEDZKhB5DHcwJATx1h4WE4sEXTq0kEHo_y2RcPM9LBkxOynrIqiTkF_0lv8HzW5fi431zdspvbmBpbh8hhMDxs3JNKXVE83DvYLU-uCvRysm5YJ46Gyiiu96rG-pH-HVLYSVFuepTCQLbWmfmL4PE53Lj0ZSzFY6W1A&publicKey=-----BEGIN%20PUBLIC%20KEY-----%0AMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv%0AvkTtwlvBsaJq7S5wA%2BkzeVOVpVWwkWdVha4s38XM%2Fpa%2Fyr47av7%2Bz3VTmvDRyAHc%0AaT92whREFpLv9cj5lTeJSibyr%2FMrm%2FYtjCZVWgaOYIhwrXwKLqPr%2F11inWsAkfIy%0AtvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0%0Ae%2Blf4s4OxQawWD79J9%2F5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb%0AV6L11BWkpzGXSW4Hv43qa%2BGSYOD2QU68Mb59oSk2OB%2BBtOLpJofmbGEGgvmwyCI9%0AMwIDAQAB%0A-----END%20PUBLIC%20KEY-----
        let data = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJwZXJzb25hbEBkb21haW4uY29tIiwicm9sZSI6InNpbmdsZSIsInV1aWQiOiIxMjM0IiwiaWF0IjoxNTE2MjM5MDIyfQ.Cc9S3KmJKeb6moIVxv-f_wOAqVZ2Hz3hnFtyDkj2uspScFvFY8mI6OkK83f8Zy7Wr_str5_lHDu3MwuHZJFnPn5D6vZYswzGRXk--9ulMq77c8lylYROZZjyEUU4GiBqTQrn8I6T9cBElvlZdKo6jOTvTKHV6hQFl2cUFd9Vi_6E_JJGHm1BEDZKhB5DHcwJATx1h4WE4sEXTq0kEHo_y2RcPM9LBkxOynrIqiTkF_0lv8HzW5fi431zdspvbmBpbh8hhMDxs3JNKXVE83DvYLU-uCvRysm5YJ46Gyiiu96rG-pH-HVLYSVFuepTCQLbWmfmL4PE53Lj0ZSzFY6W1A"
        XCTAssertNoThrow(try VerifyLicense(withLicense: data, publicKey: publicKey))
    }

    func testTeamTicket() throws {
        // https://jwt.io/#debugger-io?token=eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZWFtQGRvbWFpbi5jb20iLCJyb2xlIjoidGVhbSIsInRlYW1JRCI6IjEyMzQiLCJkZXZpY2VJRCI6IjQ1NjciLCJpYXQiOjE1MTYyMzkwMjJ9.ZDueYW67zAoM5UUheEYVDBOH3TjahH_GMW9KhlLkGpppfeT6EyvAlaHabn-uMAlSnpFW53Zr2ftoa-bN8TAmBxFJfVOqovWeQx26y2rTqqg67t0gmYNiU997DihB3c8DwLDnKNUSuc9L4Rakg7flbT984Mkk7zSzKHCedfyKbBuCbin_kby5X5bFjr_8BDGAOwhDwp9-ovcpag7Xf-FNMGqDhlpMNY1FwFEF9Z4LVzLMChDQQiGI6NuDr75T-3vGCr8i4S6e-Ju3A3-U5wFLtsp6uu9_1GDecp7qUep4HjgOAZItjPWpC0CfMpcuJkLxzKYP0xdP0cZbeQ22K-6CGQ&publicKey=-----BEGIN%20PUBLIC%20KEY-----%0AMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv%0AvkTtwlvBsaJq7S5wA%2BkzeVOVpVWwkWdVha4s38XM%2Fpa%2Fyr47av7%2Bz3VTmvDRyAHc%0AaT92whREFpLv9cj5lTeJSibyr%2FMrm%2FYtjCZVWgaOYIhwrXwKLqPr%2F11inWsAkfIy%0AtvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0%0Ae%2Blf4s4OxQawWD79J9%2F5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb%0AV6L11BWkpzGXSW4Hv43qa%2BGSYOD2QU68Mb59oSk2OB%2BBtOLpJofmbGEGgvmwyCI9%0AMwIDAQAB%0A-----END%20PUBLIC%20KEY-----
        let data = "eyJhbGciOiJSUzUxMiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZWFtQGRvbWFpbi5jb20iLCJyb2xlIjoidGVhbSIsInRlYW1JRCI6IjEyMzQiLCJkZXZpY2VJRCI6IjQ1NjciLCJpYXQiOjE1MTYyMzkwMjJ9.ZDueYW67zAoM5UUheEYVDBOH3TjahH_GMW9KhlLkGpppfeT6EyvAlaHabn-uMAlSnpFW53Zr2ftoa-bN8TAmBxFJfVOqovWeQx26y2rTqqg67t0gmYNiU997DihB3c8DwLDnKNUSuc9L4Rakg7flbT984Mkk7zSzKHCedfyKbBuCbin_kby5X5bFjr_8BDGAOwhDwp9-ovcpag7Xf-FNMGqDhlpMNY1FwFEF9Z4LVzLMChDQQiGI6NuDr75T-3vGCr8i4S6e-Ju3A3-U5wFLtsp6uu9_1GDecp7qUep4HjgOAZItjPWpC0CfMpcuJkLxzKYP0xdP0cZbeQ22K-6CGQ"
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
