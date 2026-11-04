//
//  SSHConfigCheckTests.swift
//  Pareto Security
//
//  Created by ArchitektApx on 04/11/2026.
//

@testable import Pareto_Security
import XCTest

class SSHConfigCheckTests: XCTestCase {
    /// Captured verbatim on a clean macOS 26.6.2 VM (OpenSSH 10.3p1) from
    /// `/usr/bin/ssh -G -oCanonicalizeHostname=no pareto-probe-<uuid>.invalid` with stdout and stderr merged, the way
    /// the check reads it. ssh ends its stderr lines with \r\n. Clean macOS 13.7.4, 14.8.7 and 15.7.7 VMs print the
    /// same forwardagent and stricthostkeychecking values.
    static let defaultConfig = """
    Pseudo-terminal will not be allocated because stdin is not a terminal.\r
    host pareto-probe-1f2c170c-2338-4e96-afbe-59ffe5b7aac4.invalid
    user admin
    hostname pareto-probe-1f2c170c-2338-4e96-afbe-59ffe5b7aac4.invalid
    port 22
    addressfamily any
    batchmode no
    canonicalizefallbacklocal yes
    canonicalizehostname false
    checkhostip no
    compression no
    controlmaster false
    enablesshkeysign no
    clearallforwardings no
    exitonforwardfailure no
    fingerprinthash SHA256
    forwardx11 no
    forwardx11trusted no
    gatewayports no
    gssapiauthentication no
    gssapidelegatecredentials no
    hashknownhosts no
    hostbasedauthentication no
    identitiesonly no
    kbdinteractiveauthentication yes
    nohostauthenticationforlocalhost no
    nohostauthenticationforproxycommand no
    passwordauthentication yes
    permitlocalcommand no
    proxyusefdpass no
    pubkeyauthentication true
    requesttty auto
    sessiontype default
    stdinnull no
    forkafterauthentication no
    streamlocalbindunlink no
    stricthostkeychecking ask
    tcpkeepalive yes
    tunnel false
    verifyhostkeydns false
    visualhostkey no
    updatehostkeys true
    enableescapecommandline no
    warnweakcrypto yes
    applemultipath no
    canonicalizemaxdots 1
    connectionattempts 1
    forwardx11timeout 1200
    numberofpasswordprompts 3
    serveralivecountmax 3
    serveraliveinterval 0
    requiredrsasize 1024
    obscurekeystroketiming yes
    ciphers aes128-gcm@openssh.com,aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr
    hostkeyalgorithms ssh-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,webauthn-sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,webauthn-sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256
    hostbasedacceptedalgorithms ssh-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,webauthn-sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,webauthn-sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256
    kexalgorithms ecdh-sha2-nistp256,mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256
    casignaturealgorithms ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,webauthn-sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256
    loglevel INFO
    macs hmac-sha2-256-etm@openssh.com,hmac-sha2-256,umac-64-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,umac-64@openssh.com,umac-128@openssh.com,hmac-sha2-512,hmac-sha1
    securitykeyprovider $SSH_SK_PROVIDER
    pubkeyacceptedalgorithms ssh-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,webauthn-sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ssh-ed25519@openssh.com,sk-ecdsa-sha2-nistp256@openssh.com,webauthn-sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256
    xauthlocation /usr/X11R6/bin/xauth
    identityfile ~/.ssh/id_rsa
    identityfile ~/.ssh/id_ecdsa
    identityfile ~/.ssh/id_ecdsa_sk
    identityfile ~/.ssh/id_ed25519
    identityfile ~/.ssh/id_ed25519_sk
    canonicaldomains none
    globalknownhostsfile /etc/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts2
    userknownhostsfile /Users/admin/.ssh/known_hosts /Users/admin/.ssh/known_hosts2
    revokedhostkeys none
    sendenv LANG
    sendenv LC_*
    logverbose none
    channeltimeout none
    permitremoteopen any
    addkeystoagent false
    forwardagent no
    connecttimeout none
    tunneldevice any:any
    canonicalizePermittedcnames none
    controlpersist no
    escapechar ~
    ipqos ef cs0
    rekeylimit 0 0
    streamlocalbindmask 0177
    syslogfacility USER
    """

    // MARK: - ssh -G output

    func testDefaultConfigPasses() {
        XCTAssertEqual(SSHAgentForwardingCheck.evaluate(sshG: Self.defaultConfig), true)
        XCTAssertEqual(SSHHostKeyVerificationCheck.evaluate(sshG: Self.defaultConfig), true)
    }

    func testSimilarKeysAreIgnored() {
        let output = Self.defaultConfig + "\nxforwardagent yes\nforwardagentx yes\nxstricthostkeychecking false"
        XCTAssertEqual(SSHAgentForwardingCheck.evaluate(sshG: output), true)
        XCTAssertEqual(SSHHostKeyVerificationCheck.evaluate(sshG: output), true)
    }

    func testCRLFLineEndings() {
        let output = Self.defaultConfig.replacingOccurrences(of: "\n", with: "\r\n")
        XCTAssertEqual(SSHAgentForwardingCheck.evaluate(sshG: output), true)
        XCTAssertEqual(SSHHostKeyVerificationCheck.evaluate(sshG: output), true)

        let forwarded = output.replacingOccurrences(of: "forwardagent no", with: "forwardagent yes")
        XCTAssertEqual(SSHAgentForwardingCheck.evaluate(sshG: forwarded), false)
    }

    func testMissingSettingIsNotEvaluated() {
        let output = Self.defaultConfig
            .replacingOccurrences(of: "forwardagent no", with: "")
            .replacingOccurrences(of: "stricthostkeychecking ask", with: "")
        XCTAssertNil(SSHAgentForwardingCheck.evaluate(sshG: output))
        XCTAssertNil(SSHHostKeyVerificationCheck.evaluate(sshG: output))
        XCTAssertNil(SSHAgentForwardingCheck.evaluate(sshG: ""))
    }

    func testEmptyValueIsNotEvaluated() {
        for line in ["forwardagent", "forwardagent ", "forwardagent   "] {
            let output = Self.defaultConfig.replacingOccurrences(of: "forwardagent no", with: line)
            XCTAssertNil(SSHAgentForwardingCheck.evaluate(sshG: output), line)
        }
    }

    func testStderrNoiseIsIgnored() {
        let output = Self.defaultConfig + "\nWarning: forwardagent yes\nWarning: stricthostkeychecking false"
        XCTAssertEqual(SSHAgentForwardingCheck.evaluate(sshG: output), true)
        XCTAssertEqual(SSHHostKeyVerificationCheck.evaluate(sshG: output), true)
    }

    // MARK: - ssh -G with a config file

    func testSettingsForOneHostPass() throws {
        let provider = try sshConfig("Host work.example.com\n  ForwardAgent yes\n  StrictHostKeyChecking no\n")
        let checks: [SSHConfigCheck] = [
            SSHAgentForwardingCheck(sshConfigProvider: provider),
            SSHHostKeyVerificationCheck(sshConfigProvider: provider),
        ]
        for check in checks {
            XCTAssertTrue(check.checkPasses())
            XCTAssertFalse(check.hasError)
        }
    }

    func testForwardingToAllHostsFails() throws {
        let included = try temporaryDirectory().appendingPathComponent("included.conf")
        try "Host *\n  ForwardAgent yes\n".write(to: included, atomically: true, encoding: .utf8)
        let configs = [
            "Host *\n  ForwardAgent yes\n",
            "Host *\n  ForwardAgent /tmp/agent.sock\n",
            "Host *\n  ForwardAgent $SSH_AUTH_SOCK\n",
            "Match all\n  ForwardAgent yes\n",
            "Include \(included.path)\n",
        ]

        for config in configs {
            let check = try SSHAgentForwardingCheck(sshConfigProvider: sshConfig(config))
            XCTAssertFalse(check.checkPasses(), config)
            XCTAssertFalse(check.hasError, config)
        }
    }

    func testHostKeyVerificationForAllHosts() throws {
        let configs = [
            "Host *\n  StrictHostKeyChecking no\n": false,
            "Host *\n  StrictHostKeyChecking off\n": false,
            "Host *\n  StrictHostKeyChecking accept-new\n": true,
            "Host *\n  StrictHostKeyChecking yes\n": true,
        ]

        for (config, passes) in configs {
            let check = try SSHHostKeyVerificationCheck(sshConfigProvider: sshConfig(config))
            XCTAssertEqual(check.checkPasses(), passes, config)
            XCTAssertFalse(check.hasError, config)
        }
    }

    func testInvalidConfigIsAnError() throws {
        let configs = [
            "Host *\n  FooBarBaz yes\n",
            "Host *\n  StrictHostKeyChecking maybe\n",
            "Host *\n  ForwardAgent ${PARETO_UNSET_VARIABLE}\n",
        ]

        for config in configs {
            let check = try SSHAgentForwardingCheck(sshConfigProvider: sshConfig(config))
            XCTAssertFalse(check.checkPasses(), config)
            XCTAssertTrue(check.hasError, config)
        }
    }

    func testMatchExecCannotRunCommands() throws {
        let marker = try temporaryDirectory().appendingPathComponent("executed")
        let included = try temporaryDirectory().appendingPathComponent("included.conf")
        let command = "touch '\(marker.path)'"
        try "Match exec \"\(command)\"\n".write(to: included, atomically: true, encoding: .utf8)
        let configs = [
            "Match exec \"\(command)\"\n",
            "Match !exec \"\(command)\"\n",
            "Match exec \"\(command) &\"\n",
            "Include \(included.path)\n",
        ]

        for config in configs {
            try assertConfigIsAnError(config)
            XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path), config)
        }
    }

    func testMatchExecCannotForgePassingSettings() throws {
        let forged = "echo forwardagent no >&2; echo stricthostkeychecking true >&2"
        let configs = [
            "Host *\n ForwardAgent yes\n StrictHostKeyChecking no\nMatch exec \"(sleep 0.2; \(forged)) &\"\n",
            "Match exec \"\(forged)\"\nHost *\n BadOption yes\n",
        ]
        for config in configs {
            try assertConfigIsAnError(config)
        }
    }

    func testUnmatchedExecDoesNotRun() throws {
        let marker = try temporaryDirectory().appendingPathComponent("executed")
        let provider = try sshConfig("Match host work.example.com exec \"touch '\(marker.path)'\"\n ForwardAgent yes\n")
        let check = SSHAgentForwardingCheck(sshConfigProvider: provider)

        XCTAssertTrue(check.checkPasses())
        XCTAssertFalse(check.hasError)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testSlowMatchExecIsRejectedImmediately() throws {
        for command in ["sleep 30", "sleep 30 &"] {
            let start = Date()
            try assertConfigIsAnError("Match exec \"\(command)\"\n ForwardAgent yes\n")
            XCTAssertLessThan(Date().timeIntervalSince(start), 5, command)
        }
    }

    func testCommandRunnerDoesNotParseStderrAsSettings() async throws {
        let output = try await runCMDAsync(
            app: "/bin/sh",
            args: ["-c", "echo forwardagent yes; echo stricthostkeychecking false; echo forwardagent no >&2; echo stricthostkeychecking true >&2"],
            includeStandardError: false,
            requireSuccessfulExit: true
        )

        XCTAssertEqual(SSHAgentForwardingCheck.evaluate(sshG: output), false)
        XCTAssertEqual(SSHHostKeyVerificationCheck.evaluate(sshG: output), false)
    }

    func testCommandRunnerRejectsPassingOutputOnFailure() async throws {
        do {
            _ = try await runCMDAsync(
                app: "/bin/sh",
                args: ["-c", "echo forwardagent no; echo stricthostkeychecking true; exit 255"],
                includeStandardError: false,
                requireSuccessfulExit: true
            )
            XCTFail("Failed commands must not supply passing settings")
        } catch let CommandRunnerError.unsuccessfulExit(status) {
            XCTAssertEqual(status, 255)
        }
    }

    func testCommandRunnerStillTimesOut() async throws {
        do {
            _ = try await runCMDAsync(
                app: "/bin/sleep",
                args: ["30"],
                timeout: 0.1,
                includeStandardError: false,
                requireSuccessfulExit: true
            )
            XCTFail("The command must time out")
        } catch CommandRunnerError.timedOut {}
    }

    func testReadsDefaultSSHConfig() {
        let output = SSHConfigCheck.readSSHConfig(configFile: "/dev/null")

        XCTAssertEqual(SSHAgentForwardingCheck.evaluate(sshG: output), true)
        XCTAssertEqual(SSHHostKeyVerificationCheck.evaluate(sshG: output), true)
    }

    func testSSHOutputIsNotLocalized() {
        let args = ["-p", SSHConfigCheck.sandboxProfile, SSHConfigCheck.sshBinaryPath,
                    "-F", "/dev/null", "-G", "-oCanonicalizeHostname=no", "pareto-probe.invalid"]
        let english = SSHConfigCheck.settings(fromSSHG: runCMD(app: "/usr/bin/sandbox-exec", args: args))
        let french = SSHConfigCheck.settings(fromSSHG: runCMD(
            app: "/usr/bin/sandbox-exec",
            args: args,
            environment: ProcessInfo.processInfo.environment.merging(
                ["LANG": "fr_FR.UTF-8", "LC_ALL": "fr_FR.UTF-8", "AppleLanguages": "(fr)"]
            ) { $1 }
        ))

        XCTAssertNotNil(french["forwardagent"])
        XCTAssertEqual(french["forwardagent"], english["forwardagent"])
        XCTAssertEqual(french["stricthostkeychecking"], english["stricthostkeychecking"])
    }

    private func assertConfigIsAnError(_ config: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let provider = try sshConfig(config)
        let checks: [SSHConfigCheck] = [
            SSHAgentForwardingCheck(sshConfigProvider: provider),
            SSHHostKeyVerificationCheck(sshConfigProvider: provider),
        ]
        for check in checks {
            XCTAssertFalse(check.checkPasses(), config, file: file, line: line)
            XCTAssertTrue(check.hasError, config, file: file, line: line)
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func sshConfig(_ config: String) throws -> () -> String {
        let configFile = try temporaryDirectory().appendingPathComponent("config")
        try config.write(to: configFile, atomically: true, encoding: .utf8)
        return { SSHConfigCheck.readSSHConfig(configFile: configFile.path) }
    }
}
