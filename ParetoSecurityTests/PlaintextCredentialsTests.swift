//
//  PlaintextCredentialsTests.swift
//  Pareto Security
//

@testable import Pareto_Security
import XCTest

class PlaintextCredentialsTests: XCTestCase {
    /// AWS's documented temporary key id, split so secret scanners do not match it.
    static let awsTemporaryKeyID = "ASIA" + "IOSFODNN7EXAMPLE"

    /// `~/.aws/credentials` from `aws configure` and `aws configure set` (aws-cli 2.39.7, macOS 26.6.2) with AWS's
    /// documented example keys; `temp` also has a session token.
    static let awsCredentials = """
    [default]
    aws_access_key_id = AKIAIOSFODNN7EXAMPLE
    aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
    [work]
    aws_access_key_id = AKIAI44QH8DHBEXAMPLE
    aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
    [temp]
    aws_access_key_id = \(awsTemporaryKeyID)
    aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
    aws_session_token = IQoJb3JpZ2luX2IQoJb3JpZ2luX2IQoJb3JpZ2luX2IQoJb3JpZ2luX2IQoJb3JpZVERYLONGSTRINGEXAMPLE

    """

    /// `~/.aws/config` from `aws configure set` (aws-cli 2.39.7, macOS 26.6.2): SSO, credential_process and an
    /// assumed role, no secrets.
    static let awsConfig = """
    [default]
    region = eu-central-1
    output = json
    [profile work]
    region = us-east-1
    [profile sso]
    sso_session = my-sso
    sso_account_id = 111122223333
    sso_role_name = ReadOnly
    region = eu-central-1
    [profile vault]
    credential_process = /usr/local/bin/aws-vault exec work --json
    [profile assume]
    role_arn = arn:aws:iam::111122223333:role/Admin
    source_profile = work

    """

    /// The same config with keys added by hand; `aws configure list --profile inconfig` reports them as `config-file`.
    static let awsConfigWithKeys = awsConfig + """
    [profile inconfig]
    aws_access_key_id = AKIAI44QH8DHBEXAMPLE
    aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY

    """

    /// `~/.git-credentials` from `git credential-store store` (Apple Git-157 and Homebrew git 2.56.0, identical).
    static let gitCredentials = """
    http://bob:secret@git.internal.example
    https://alice%40example.com:p%40ss%2fw0rd%3a1%202@gitlab.example.com%3a8443
    https://octocat:fake-token-0123456789abcdef@github.com

    """

    /// `~/.config/git/credentials` written by the same git versions when only that file exists.
    static let gitXDGCredentials = """
    https://octocat:fake-token-0123456789abcdef@github.com

    """

    /// `config.json` after `docker login` to a local registry (Docker client 29.9.3 on Colima, no credential helper).
    static let dockerConfig = """
    {
    \t"auths": {
    \t\t"127.0.0.1:5055": {
    \t\t\t"auth": "dGVzdHVzZXI6dGVzdC1wYXNzd29yZC0xMjM="
    \t\t},
    \t\t"localhost:5055": {
    \t\t\t"auth": "dGVzdHVzZXI6dGVzdC1wYXNzd29yZC0xMjM="
    \t\t}
    \t}
    }
    """

    /// The same `config.json` after `docker logout` from both registries.
    static let dockerConfigAfterLogout = """
    {
    \t"auths": {}
    }
    """

    /// Fake token with the prefix and length of the captured one, split so secret scanners do not match it.
    static let ghToken = "gho_" + "rg6fIr5dnfZ0yOpuYhxSsFg3PkAoPp97M5cV"

    /// `hosts.yml` from gh 2.25.1 `gh auth login` (macOS 26.6.2), token and account name replaced.
    static let ghHostsLegacy = """
    github.com:
        oauth_token: \(ghToken)
        user: octocat
        git_protocol: https

    """

    /// `hosts.yml` from gh 2.103.3 `gh auth login --insecure-storage`, token and account name replaced.
    static let ghHostsInsecureStorage = """
    github.com:
        users:
            octocat:
                oauth_token: \(ghToken)
        git_protocol: https
        user: octocat

    """

    /// `hosts.yml` after a normal gh 2.103.3 login on top of the gh 2.25.1 file; the token moved to the keychain.
    static let ghHostsKeychain = """
    github.com:
        user: octocat
        git_protocol: https
        users:
            octocat:

    """

    // MARK: - Validators

    func testAWSCredentialsFailOnlyLongTermProfiles() {
        XCTAssertEqual(PlaintextCredentialsCheck.awsProfilesWithLongTermKeys(Self.awsCredentials, isConfigFile: false), ["default", "work"])
    }

    func testAWSConfigFailsOnlyProfilesWithKeys() {
        XCTAssertEqual(PlaintextCredentialsCheck.awsProfilesWithLongTermKeys(Self.awsConfig, isConfigFile: true), [])
        XCTAssertEqual(PlaintextCredentialsCheck.awsProfilesWithLongTermKeys(Self.awsConfigWithKeys, isConfigFile: true), ["inconfig"])
    }

    func testAWSEdgeCases() {
        let contents = [
            "# comment",
            "; comment",
            "",
            "[default]",
            "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "[old]",
            "aws_secret_access_key_old = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "[empty]",
            "aws_secret_access_key =",
            "[emptytoken]",
            "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "aws_session_token =",
            "[sso-session my-sso]",
            "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "[profile security]",
            "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "aws_security_token = IQoJb3JpZ2luX2IQoJb3JpZVERYLONGSTRINGEXAMPLE",
            "[profile asia]",
            "aws_access_key_id = \(Self.awsTemporaryKeyID)",
            "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "[profile commented] # main",
            "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "[profile \"quoted name\"]",
            "AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "[profile crlf]",
            "aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        ].joined(separator: "\r\n")

        XCTAssertEqual(
            PlaintextCredentialsCheck.awsProfilesWithLongTermKeys(contents, isConfigFile: true),
            ["default", "commented", "quoted name", "crlf"]
        )
        XCTAssertEqual(
            PlaintextCredentialsCheck.awsProfilesWithLongTermKeys(contents, isConfigFile: false),
            ["default", "emptytoken", "sso-session my-sso", "profile commented", "profile \"quoted name\"", "profile crlf"]
        )
    }

    func testGitCredentialsDecodeHosts() {
        XCTAssertEqual(
            PlaintextCredentialsCheck.gitHostsWithPasswords(Self.gitCredentials),
            ["git.internal.example", "gitlab.example.com:8443", "github.com"]
        )
        let edgeCases = [
            "", "https://octocat@github.com", "https://octocat:@example.org", "not a url",
            "https://u:p@ghe.example.com/org/repo.git", "https://u:p@query.example?token=x", "https://u:p@ss@at.example#x", "",
        ].joined(separator: "\r\n")
        XCTAssertEqual(
            PlaintextCredentialsCheck.gitHostsWithPasswords(edgeCases),
            ["ghe.example.com", "query.example", "at.example"]
        )
    }

    func testDockerConfig() {
        XCTAssertEqual(PlaintextCredentialsCheck.dockerRegistriesWithLogins(Self.dockerConfig), ["127.0.0.1:5055", "localhost:5055"])
        XCTAssertEqual(PlaintextCredentialsCheck.dockerRegistriesWithLogins(Self.dockerConfigAfterLogout), [])
        XCTAssertEqual(
            PlaintextCredentialsCheck.dockerRegistriesWithLogins("""
            {"credsStore": "osxkeychain", "auths": {"a.example": {}, "b.example": {"auth": ""}, "c.example": {"identitytoken": "x"},
            "d.example": {"username": "u", "password": "x"}}}
            """),
            ["c.example", "d.example"]
        )
        for empty in ["", "{}", "{\"auths\": null}"] {
            XCTAssertEqual(PlaintextCredentialsCheck.dockerRegistriesWithLogins(empty), [], empty)
        }
        for invalid in ["{\"auths\": {", "{\"auths\": []}", "[]"] {
            XCTAssertNil(PlaintextCredentialsCheck.dockerRegistriesWithLogins(invalid), invalid)
        }
    }

    func testGhHosts() {
        XCTAssertEqual(PlaintextCredentialsCheck.ghHostsWithTokens(Self.ghHostsLegacy), ["github.com"])
        XCTAssertEqual(PlaintextCredentialsCheck.ghHostsWithTokens(Self.ghHostsInsecureStorage), ["github.com"])
        XCTAssertEqual(PlaintextCredentialsCheck.ghHostsWithTokens(Self.ghHostsKeychain), [])

        let severalHosts = Self.ghHostsKeychain + """
        # comment
        ghe.example.com:
            oauth_token_old: \(Self.ghToken)
            oauth_token: ""
        ghe.null.example:
            oauth_token: null
        ghe.commented.example: # main
            oauth_token: \(Self.ghToken)
        "ghe.other.example":
            users:
                octocat:
                    oauth_token: \(Self.ghToken)
                hubot:
                    oauth_token: \(Self.ghToken)

        """
        XCTAssertEqual(PlaintextCredentialsCheck.ghHostsWithTokens(severalHosts), ["ghe.commented.example", "ghe.other.example"])
    }

    // MARK: - Check

    private func makeHome(_ files: [String: String]) throws -> URL {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for (path, contents) in files {
            let url = home.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: url, atomically: true, encoding: .utf8)
        }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: home) }
        return home
    }

    func testDoesNotRunWithoutCredentialFiles() throws {
        let check = try PlaintextCredentialsCheck(homeDirectory: makeHome([".config/git/config": ""]), environment: [:])
        check.configure()

        XCTAssertFalse(check.isRunnable)
        XCTAssertFalse(check.showInMenu)
    }

    func testPassesWithoutPlaintextCredentials() throws {
        let home = try makeHome([
            ".aws/config": Self.awsConfig,
            ".docker/config.json": Self.dockerConfigAfterLogout,
            ".config/gh/hosts.yml": Self.ghHostsKeychain,
        ])
        let check = PlaintextCredentialsCheck(homeDirectory: home, environment: [:])
        check.configure()

        XCTAssertTrue(check.isRunnable)
        XCTAssertTrue(check.checkPasses())
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(check.details, "None")
    }

    func testFailsWithPlaintextCredentials() throws {
        let home = try makeHome([
            ".aws/credentials": Self.awsCredentials,
            ".aws/config": Self.awsConfigWithKeys,
            ".git-credentials": Self.gitCredentials,
            ".config/git/credentials": Self.gitXDGCredentials,
            ".docker/config.json": Self.dockerConfig,
            ".config/gh/hosts.yml": Self.ghHostsInsecureStorage,
        ])
        let check = PlaintextCredentialsCheck(homeDirectory: home, environment: [:])

        XCTAssertFalse(check.checkPasses())
        XCTAssertFalse(check.hasError)
        XCTAssertEqual(check.details, """
        - ~/.aws/credentials profile default has a long-term access key; use aws-vault or see the docs for alternatives
        - ~/.aws/credentials profile work has a long-term access key; use aws-vault or see the docs for alternatives
        - ~/.aws/config profile inconfig has a long-term access key; use aws-vault or see the docs for alternatives
        - ~/.git-credentials stores a password for git.internal.example; switch to credential.helper osxkeychain
        - ~/.git-credentials stores a password for gitlab.example.com:8443; switch to credential.helper osxkeychain
        - ~/.git-credentials stores a password for github.com; switch to credential.helper osxkeychain
        - ~/.config/git/credentials stores a password for github.com; switch to credential.helper osxkeychain
        - ~/.docker/config.json stores a login for 127.0.0.1:5055; set a credsStore
        - ~/.docker/config.json stores a login for localhost:5055; set a credsStore
        - ~/.config/gh/hosts.yml stores a token for github.com; log in again with gh 2.26 or later, without --insecure-storage
        """)
    }

    func testDetailsNeverContainSecretsOrUsernames() throws {
        let home = try makeHome([
            ".aws/credentials": Self.awsCredentials,
            ".aws/config": Self.awsConfigWithKeys,
            ".git-credentials": Self.gitCredentials
                + "https://bob:secret@query.example?token=querysecret\nhttps://alice:p@ss@at.example#fragsecret\n",
            ".docker/config.json": Self.dockerConfig,
            ".config/gh/hosts.yml": Self.ghHostsInsecureStorage + "ghe.example.com: # commentsecret\n    oauth_token: \(Self.ghToken)\n",
        ])
        let details = PlaintextCredentialsCheck(homeDirectory: home, environment: [:]).details
        let secrets = [
            "AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "AKIAI44QH8DHBEXAMPLE", "je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY",
            "bob", "secret", "alice", "p%40ss", "p@ss", "fake-token", "octocat",
            "dGVzdHVzZXI6dGVzdC1wYXNzd29yZC0xMjM=", "testuser", Self.ghToken, "querysecret", "fragsecret", "commentsecret",
        ]

        XCTAssertTrue(details.contains("query.example;") && details.contains("at.example;") && details.contains("ghe.example.com;"))
        for secret in secrets {
            XCTAssertFalse(details.contains(secret), secret)
        }
    }

    func testUsesXDGConfigHome() throws {
        let home = try makeHome([
            ".config/gh/hosts.yml": Self.ghHostsLegacy,
            "xdg/gh/hosts.yml": Self.ghHostsLegacy,
            "xdg/git/credentials": Self.gitXDGCredentials,
        ])
        let check = PlaintextCredentialsCheck(
            homeDirectory: home,
            environment: ["XDG_CONFIG_HOME": home.appendingPathComponent("xdg").path]
        )

        XCTAssertEqual(check.details, """
        - $XDG_CONFIG_HOME/git/credentials stores a password for github.com; switch to credential.helper osxkeychain
        - ~/.config/gh/hosts.yml stores a token for github.com; log in again with gh 2.26 or later, without --insecure-storage
        - $XDG_CONFIG_HOME/gh/hosts.yml stores a token for github.com; log in again with gh 2.26 or later, without --insecure-storage
        """)
    }

    func testUnreadableFileIsAnError() throws {
        let home = try makeHome([
            ".docker/config.json": "{\"auths\": {",
            ".config/gh/hosts.yml": Self.ghHostsLegacy,
        ])
        let hosts = home.appendingPathComponent(".config/gh/hosts.yml")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: hosts.path)
        let check = PlaintextCredentialsCheck(homeDirectory: home, environment: [:])

        XCTAssertFalse(check.checkPasses())
        XCTAssertTrue(check.hasError)
        XCTAssertEqual(check.details, """
        - ~/.docker/config.json could not be read
        - ~/.config/gh/hosts.yml could not be read
        """)
    }
}
