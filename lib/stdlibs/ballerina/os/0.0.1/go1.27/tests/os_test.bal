// Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/test;
import ballerina/io;

@test:Config {}
isolated function testGetEnvNegative() {
    test:assertEquals(getEnv("JAVA_XXXX"), "");
}

@test:Config {}
function testGetUserHome() {
    test:assertEquals(getUserHome(), getEnv(isWindowsEnvironment() ? "USERPROFILE" : "HOME"));
}

@test:Config {}
function testGetUsername() {
    string expected = getEnv(isWindowsEnvironment() ? "USERNAME" : "USER");
    if expected == "" {
        test:assertNotEquals(getUsername(), "");
    } else {
        test:assertEquals(getUsername(), expected);
    }
}

function setEnvDataProvider() returns (string[][]) {
    return [
        ["foo", "test1"],
        ["0x00", "test2"],
        ["!@#$%^&*()_+~", "test3"],
        ["key with spaces", "test 4"]
    ];
}

@test:Config {
    dataProvider: setEnvDataProvider
}
function testSetEnv(string key, string value) {
    Error? result = setEnv(key, value);
    if result is Error {
        test:assertFail("failed to set environment variable with key " + key + " : " + result.message());
    } else {
        test:assertEquals(getEnv(key), value);
    }
}

function setEnvDataProviderNegative() returns (string[][]) {
    return [
        ["", "test1", "The parameter key cannot be an empty string"],
        ["==", "test2", "The parameter key cannot be == sign"]
    ];
}

@test:Config {
    dataProvider: setEnvDataProviderNegative
}
function testSetEnvNegative(string key, string value, string errorMessage) {
    Error? result = setEnv(key, value);
    if result is Error {
        test:assertEquals(result.message(), errorMessage);
    } else {
        test:assertFail("setEnv did not return an error for " + key + " as key");
    }
}

function unsetEnvDataProvider() returns (string[][]) {
    return [
        ["foo", "test1"],
        ["0x00", "test2"],
        ["!@#$%^&*()_+~", "test3"],
        ["key with spaces", "test 4"]
    ];
}

@test:Config {
    dataProvider: unsetEnvDataProvider
}
function testUnsetEnv(string key, string value) {
    Error? result = setEnv(key, value);
    if result is Error {
        test:assertFail("failed to set environment variable with key " + key + " : " + result.message());
    } else {
        test:assertEquals(getEnv(key), value);
        result = unsetEnv(key);
        if result is Error {
            test:assertFail("failed to unset environment variable with key " + key + " : " + result.message());
        } else {
            test:assertFalse(envVariableExists(key), "environment variable with key " + key + " has not been removed");
        }
    }
}

@test:Config {}
function testUnsetEnvNegative() {
    Error? result = unsetEnv("");
    if result is Error {
        test:assertEquals(result.message(), "The parameter key cannot be an empty string");
    } else {
        test:assertFail("setEnv did not return an error for empty string as key");
    }
}

@test:Config {}
function testListEnv() {
    map<string> env = listEnv();
    test:assertTrue(env.length() > 0);
}

function envVariableExists(string key) returns boolean {
    map<string> env = listEnv();
    string? value = env[key];
    return value is string && value != "";
}

@test:Config {}
function testExec() returns error? {
    Process process = check exec(shellCommand("echo hello world"));
    int exitCode = check process.waitForExit();
    test:assertEquals(exitCode, 0);

    byte[] outputBytes = check process.output();
    string outputString = check string:fromBytes(outputBytes);
    test:assertEquals(outputString.trim(), "hello world");
}

@test:Config {}
function testExecOutputWithoutWaitForExit() returns error? {
    Process process = check exec(shellCommand("echo hello world"));

    byte[] outputBytes = check process.output();
    string outputString = check string:fromBytes(outputBytes);
    test:assertEquals(outputString.trim(), "hello world");
}

@test:Config {}
function testExecWithOutputStdOut() returns error? {
    Process process = check exec(shellCommand("echo hello world"));
    int exitCode = check process.waitForExit();
    test:assertEquals(exitCode, 0);

    byte[] stdOutBytes = check process.output(io:stdout);
    string stdOutString = check string:fromBytes(stdOutBytes);
    test:assertTrue(stdOutString.includes("hello world"));

    byte[] stdErrBytes = check process.output(io:stderr);
    string stdErrString = check string:fromBytes(stdErrBytes);
    test:assertFalse(stdErrString.includes("hello world"));
}

@test:Config {}
function testExecWithOutputStdErr() returns error? {
    Process process = check exec(shellCommand("echo hello world 1>&2"));
    int exitCode = check process.waitForExit();
    test:assertEquals(exitCode, 0);

    byte[] stdOutBytes = check process.output(io:stdout);
    string stdOutString = check string:fromBytes(stdOutBytes);
    test:assertFalse(stdOutString.includes("hello world"));

    byte[] stdErrBytes = check process.output(io:stderr);
    string stdErrString = check string:fromBytes(stdErrBytes);
    test:assertTrue(stdErrString.includes("hello world"));
}

@test:Config {}
function testExecWithEnvironmentVariable() returns error? {
    Process process = check exec(shellCommand(isWindowsEnvironment() ? "echo %OS_TEST_VAR%" : "echo $OS_TEST_VAR"),
        OS_TEST_VAR = "from parent");
    int exitCode = check process.waitForExit();
    test:assertEquals(exitCode, 0);

    byte[] outputBytes = check process.output();
    string outputString = check string:fromBytes(outputBytes);
    test:assertEquals(outputString.trim(), "from parent");
}

// Whether output() fails after exit() is JDK stream behaviour, so only the package-defined error prefix is asserted.
@test:Config {}
function testExecExit() returns error? {
    Process process = check exec(shellCommand("echo hello world"));
    process.exit();

    int _ = check process.waitForExit();

    byte[]|Error outputBytes = process.output();
    if outputBytes is Error {
        test:assertEquals(outputBytes.message().indexOf("Failed to read the output of the process: "), 0, outputBytes.message());
    }
}

// The suffix after the package-defined prefix is the platform's own exec error, so only the prefix is asserted.
@test:Config {}
function testExecNegative() returns error? {
    Process|Error process = exec({value: "foo"});
    if process is Error {
        test:assertEquals(process.message().indexOf("Failed to retrieve the process object: "), 0, process.message());
    } else {
        test:assertFail("Expected error message does not match");
    }
}

isolated function isWindowsEnvironment() returns boolean {
    return getEnv("OS") == "Windows_NT";
}

isolated function shellCommand(string script) returns Command {
    return isWindowsEnvironment() ? {value: "cmd", arguments: ["/c", script]} : {value: "sh", arguments: ["-c", script]};
}
