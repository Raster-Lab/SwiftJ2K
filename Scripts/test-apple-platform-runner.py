#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Failure-path regression checks for platform qualification evidence."""
import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("apple_runner", Path(__file__).with_name("test-apple-platforms.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.discovery = {"errors": [], "values": [{"disabledTests": [], "enabledTests": [
            {"identifier": "Tests/example()"}, {"identifier": "Tests/parameters(_:)"}]}]}
        self.destination = {"platform": "watchOS Simulator", "udid": "chosen-device"}
        self.summary = {"result": "Passed", "passedTests": 2, "totalTestCount": 2,
                        "failedTests": 0, "skippedTests": 0, "expectedFailures": 0,
                        "devicesAndConfigurations": [{"device": {"platform": "watchOS Simulator",
                            "architecture": "arm64", "deviceId": "chosen-device", "osVersion": "27.0"},
                            "passedTests": 3, "failedTests": 0, "skippedTests": 0, "expectedFailures": 0}]}

    def test_parameterised_cases_are_distinct_from_declarations(self):
        count = runner.enumeration_count(self.discovery)
        self.assertEqual(count, 2)
        self.assertEqual(runner.validate_summary(self.summary, count, self.destination, "27.0"), 3)

    def test_disabled_empty_duplicate_and_failed_discovery_are_rejected(self):
        mutations = [
            {"errors": ["bundle failed"]}, {"values": []},
            {"values": [{"disabledTests": [{"identifier": "Tests/disabled()"}], "enabledTests": []}]},
            {"values": [{"disabledTests": [], "enabledTests": []}]},
            {"values": [{"disabledTests": [], "enabledTests": [{"identifier": "same"}, {"identifier": "same"}]}]},
        ]
        for mutation in mutations:
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                runner.enumeration_count(dict(self.discovery, **mutation))

    def test_a_zero_exit_or_pass_banner_cannot_hide_missing_or_failed_tests(self):
        for key, value in (("passedTests", 0), ("passedTests", 1), ("totalTestCount", 3),
                           ("failedTests", 1), ("skippedTests", 1), ("expectedFailures", 1), ("result", "Failed")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                runner.validate_summary(dict(self.summary, **{key: value}), 2, self.destination, "27.0")

    def test_wrong_platform_os_architecture_or_device_is_rejected(self):
        for key, value in (("platform", "iOS Simulator"), ("osVersion", "26.0"),
                           ("architecture", "x86_64"), ("deviceId", "another-device")):
            summary = copy.deepcopy(self.summary)
            summary["devicesAndConfigurations"][0]["device"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                runner.validate_summary(summary, 2, self.destination, "27.0")

    def test_device_failures_and_ambiguous_destinations_are_rejected(self):
        for key in ("failedTests", "skippedTests", "expectedFailures"):
            summary = copy.deepcopy(self.summary)
            summary["devicesAndConfigurations"][0][key] = 1
            with self.subTest(key=key), self.assertRaises(ValueError):
                runner.validate_summary(summary, 2, self.destination, "27.0")
        for entries in ([], self.summary["devicesAndConfigurations"] * 2):
            with self.subTest(entries=entries), self.assertRaises(ValueError):
                runner.validate_summary(dict(self.summary, devicesAndConfigurations=entries), 2, self.destination, "27.0")


if __name__ == "__main__":
    unittest.main()
