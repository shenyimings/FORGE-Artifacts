//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import "../../../src/state/oracle/ReportsVariants.sol";

contract ReportsVariantsInputs {
    function set(uint256 _idx, ReportsVariants.ReportVariantDetails calldata _val) external {
        ReportsVariants.set(_idx, _val);
    }

    function indexOfReport(bytes32 _variant) external returns (int256) {
        return ReportsVariants.indexOfReport(_variant);
    }

    function push(ReportsVariants.ReportVariantDetails calldata _variant) external {
        ReportsVariants.push(_variant);
    }

    function getReportAtIndex(uint256 _idx) external returns (ReportsVariants.ReportVariantDetails memory) {
        return ReportsVariants.get()[_idx];
    }
}

contract ReportsVariantsTest is Test {
    ReportsVariantsInputs inputs;
    ReportsVariants.ReportVariantDetails _val;

    function setUp() public {
        inputs = new ReportsVariantsInputs();
        _val = ReportsVariants.ReportVariantDetails({variant: keccak256(abi.encode("1")), votes: 1});
        inputs.push(_val);
    }

    function testSetReportsVariants() public {
        _val.votes = 2;
        inputs.set(0, _val);
        assertEq(2, inputs.getReportAtIndex(0).votes);
    }

    function testIndexOfReport() public {
        assertEq(-1, inputs.indexOfReport(keccak256(abi.encode("2"))));
        _val = ReportsVariants.ReportVariantDetails({variant: keccak256(abi.encode("2")), votes: 1});
        inputs.push(_val);
        assertEq(1, inputs.indexOfReport(keccak256(abi.encode("2"))));
    }
}
