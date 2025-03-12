// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { D03ProtocolDefaults, console2, LibAdmin, LibConstants, LibHelpers } from "./defaults/D03ProtocolDefaults.sol";
import { MockAccounts } from "test/utils/users/MockAccounts.sol";
import { Vm } from "forge-std/Vm.sol";
import { TradingCommissionsBasisPoints, PolicyCommissionsBasisPoints } from "../src/diamonds/nayms/interfaces/FreeStructs.sol";
import { INayms, IDiamondCut } from "src/diamonds/nayms/INayms.sol";
import { LibFeeRouterFixture } from "./fixtures/LibFeeRouterFixture.sol";

contract T02AdminTest is D03ProtocolDefaults, MockAccounts {
    LibFeeRouterFixture internal libFeeRouterFixture = new LibFeeRouterFixture();

    function setUp() public virtual override {
        super.setUp();

        libFeeRouterFixture = new LibFeeRouterFixture();
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](5);
        functionSelectors[0] = libFeeRouterFixture.payPremiumCommissions.selector;
        functionSelectors[1] = libFeeRouterFixture.payTradingCommissions.selector;
        functionSelectors[2] = libFeeRouterFixture.calculateTradingCommissionsFixture.selector;
        functionSelectors[3] = libFeeRouterFixture.getTradingCommissionsBasisPointsFixture.selector;
        functionSelectors[4] = libFeeRouterFixture.getPremiumCommissionBasisPointsFixture.selector;

        // Diamond cut this fixture contract into our nayms diamond in order to test against the diamond
        cut[0] = IDiamondCut.FacetCut({ facetAddress: address(libFeeRouterFixture), action: IDiamondCut.FacetCutAction.Add, functionSelectors: functionSelectors });

        nayms.diamondCut(cut, address(0), "");
    }

    function testGetSystemId() public {
        assertEq(nayms.getSystemId(), LibHelpers._stringToBytes32(LibConstants.SYSTEM_IDENTIFIER));
    }

    function testSetEquilibriumLevelFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.setEquilibriumLevel(50);
        vm.stopPrank();
    }

    function testSetEquilibriumLevel() public {
        vm.recordLogs();
        uint256 orig = nayms.getEquilibriumLevel();
        nayms.setEquilibriumLevel(50);
        assertEq(nayms.getEquilibriumLevel(), 50);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("EquilibriumLevelUpdated(uint256,uint256)"));
        (uint256 oldV, uint256 newV) = abi.decode(entries[0].data, (uint256, uint256));
        assertEq(oldV, orig);
        assertEq(newV, 50);
    }

    function testFuzzSetEquilibriumLevel(uint256 _newLevel) public {
        nayms.setEquilibriumLevel(_newLevel);
    }

    function testSetMaxDiscountFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.setMaxDiscount(70);
        vm.stopPrank();
    }

    function testSetMaxDiscount() public {
        uint256 orig = nayms.getMaxDiscount();

        vm.recordLogs();

        nayms.setMaxDiscount(70);
        assertEq(nayms.getMaxDiscount(), 70);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("MaxDiscountUpdated(uint256,uint256)"));
        (uint256 oldV, uint256 newV) = abi.decode(entries[0].data, (uint256, uint256));
        assertEq(oldV, orig);
        assertEq(newV, 70);
    }

    function testFuzzSetMaxDiscount(uint256 _newDiscount) public {
        nayms.setMaxDiscount(_newDiscount);
    }

    function testSetTargetNaymSAllocationFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.setTargetNaymsAllocation(70);
        vm.stopPrank();
    }

    function testGetActualNaymsAllocation() public {
        assertEq(nayms.getActualNaymsAllocation(), 0);
    }

    function testSetTargetNaymsAllocation() public {
        uint256 orig = nayms.getTargetNaymsAllocation();

        vm.recordLogs();

        nayms.setTargetNaymsAllocation(70);
        assertEq(nayms.getTargetNaymsAllocation(), 70);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("TargetNaymsAllocationUpdated(uint256,uint256)"));
        (uint256 oldV, uint256 newV) = abi.decode(entries[0].data, (uint256, uint256));
        assertEq(oldV, orig);
        assertEq(newV, 70);
    }

    function testFuzzSetTargetNaymsAllocation(uint256 _newTarget) public {
        nayms.setTargetNaymsAllocation(_newTarget);
    }

    function testSetDiscountTokenFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.setDiscountToken(LibConstants.DAI_CONSTANT);
        vm.stopPrank();
    }

    function testSetDiscountToken() public {
        address orig = nayms.getDiscountToken();

        vm.recordLogs();

        nayms.setDiscountToken(LibConstants.DAI_CONSTANT);
        assertEq(nayms.getDiscountToken(), LibConstants.DAI_CONSTANT);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("DiscountTokenUpdated(address,address)"));
        (address oldV, address newV) = abi.decode(entries[0].data, (address, address));
        assertEq(oldV, orig);
        assertEq(newV, LibConstants.DAI_CONSTANT);
    }

    function testFuzzSetDiscountToken(address _newToken) public {
        nayms.setDiscountToken(_newToken);
    }

    function testSetPoolFeeFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.setPoolFee(4000);
        vm.stopPrank();
    }

    function testSetPoolFee() public {
        uint256 orig = nayms.getPoolFee();

        vm.recordLogs();

        nayms.setPoolFee(4000);
        assertEq(nayms.getPoolFee(), 4000);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("PoolFeeUpdated(uint256,uint256)"));
        (uint256 oldV, uint256 newV) = abi.decode(entries[0].data, (uint256, uint256));
        assertEq(oldV, orig);
        assertEq(newV, 4000);
    }

    function testFuzzSetPoolFee(uint24 _newFee) public {
        nayms.setPoolFee(_newFee);
    }

    function testSetCoefficientFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.setCoefficient(100);
        vm.stopPrank();
    }

    function testSetCoefficientFailIfValueTooHigh() public {
        vm.expectRevert("Coefficient too high");
        nayms.setCoefficient(1001);
    }

    function testSetCoefficient() public {
        uint256 orig = nayms.getRewardsCoefficient();

        vm.recordLogs();

        nayms.setCoefficient(100);
        assertEq(nayms.getRewardsCoefficient(), 100);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("CoefficientUpdated(uint256,uint256)"));
        (uint256 oldV, uint256 newV) = abi.decode(entries[0].data, (uint256, uint256));
        assertEq(oldV, orig);
        assertEq(newV, 100);
    }

    function testFuzzSetCoefficient(uint256 _newCoefficient) public {
        _newCoefficient = bound(_newCoefficient, 0, 1000);
        nayms.setCoefficient(_newCoefficient);
    }

    function testGetMaxDividendDenominationsDefaultValue() public {
        assertEq(nayms.getMaxDividendDenominations(), 1);
    }

    function testSetMaxDividendDenominationsFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.setMaxDividendDenominations(100);
        vm.stopPrank();
    }

    function testSetMaxDividendDenominationsFailIfLowerThanBefore() public {
        nayms.setMaxDividendDenominations(2);

        vm.expectRevert("_updateMaxDividendDenominations: cannot reduce");
        nayms.setMaxDividendDenominations(2);

        nayms.setMaxDividendDenominations(3);
    }

    function testSetMaxDividendDenominations() public {
        uint256 orig = nayms.getMaxDividendDenominations();

        vm.recordLogs();

        nayms.setMaxDividendDenominations(100);
        assertEq(nayms.getMaxDividendDenominations(), 100);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("MaxDividendDenominationsUpdated(uint8,uint8)"));
        (uint8 oldV, uint8 newV) = abi.decode(entries[0].data, (uint8, uint8));
        assertEq(oldV, orig);
        assertEq(newV, 100);
    }

    function testAddSupportedExternalTokenFailIfNotAdmin() public {
        vm.startPrank(account1);
        vm.expectRevert("not a system admin");
        nayms.addSupportedExternalToken(LibConstants.DAI_CONSTANT);
        vm.stopPrank();
    }

    function testAddSupportedExternalToken() public {
        address[] memory orig = nayms.getSupportedExternalTokens();

        vm.recordLogs();

        nayms.addSupportedExternalToken(LibConstants.DAI_CONSTANT);
        address[] memory v = nayms.getSupportedExternalTokens();
        assertEq(v.length, orig.length + 1);
        assertEq(v[v.length - 1], LibConstants.DAI_CONSTANT);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("SupportedTokenAdded(address)"));
        address tok = abi.decode(entries[0].data, (address));
        assertEq(tok, LibConstants.DAI_CONSTANT);
    }

    function testIsSupportedToken() public {
        bytes32 id = LibHelpers._getIdForAddress(LibConstants.DAI_CONSTANT);

        assertFalse(nayms.isSupportedExternalToken(id));

        nayms.addSupportedExternalToken(LibConstants.DAI_CONSTANT);

        assertTrue(nayms.isSupportedExternalToken(id));
    }

    function testAddSupportedExternalTokenIfAlreadyAdded() public {
        address[] memory orig = nayms.getSupportedExternalTokens();

        vm.recordLogs();

        nayms.addSupportedExternalToken(LibConstants.DAI_CONSTANT);
        nayms.addSupportedExternalToken(LibConstants.DAI_CONSTANT);

        address[] memory v = nayms.getSupportedExternalTokens();
        assertEq(v.length, orig.length + 1);
        assertEq(v[v.length - 1], LibConstants.DAI_CONSTANT);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries[0].topics.length, 1);
        assertEq(entries[0].topics[0], keccak256("SupportedTokenAdded(address)"));
    }

    function testSetTradingCommissionsBasisPoints() public {
        // must add up to 10000
        vm.expectRevert("trading commission BPs must sum up to 10000");
        nayms.setTradingCommissionsBasisPoints(
            TradingCommissionsBasisPoints({
                tradingCommissionTotalBP: 41,
                tradingCommissionNaymsLtdBP: 5001,
                tradingCommissionNDFBP: 2500,
                tradingCommissionSTMBP: 2499,
                tradingCommissionMakerBP: 1
            })
        );

        TradingCommissionsBasisPoints memory s = TradingCommissionsBasisPoints({
            tradingCommissionTotalBP: 41,
            tradingCommissionNaymsLtdBP: 5001,
            tradingCommissionNDFBP: 2499,
            tradingCommissionSTMBP: 2499,
            tradingCommissionMakerBP: 1
        });

        // must be sys admin
        vm.prank(account9);
        vm.expectRevert("not a system admin");
        nayms.setTradingCommissionsBasisPoints(s);
        vm.stopPrank();

        // assert happy path
        nayms.setTradingCommissionsBasisPoints(s);

        TradingCommissionsBasisPoints memory result = nayms.getTradingCommissionsBasisPoints();

        assertEq(s.tradingCommissionTotalBP, result.tradingCommissionTotalBP, "tradingCommissionTotalBP not matched");
        assertEq(s.tradingCommissionNaymsLtdBP, result.tradingCommissionNaymsLtdBP, "tradingCommissionNaymsLtdBP not matched");
        assertEq(s.tradingCommissionNDFBP, result.tradingCommissionNDFBP, "tradingCommissionNDFBP not matched");
        assertEq(s.tradingCommissionSTMBP, result.tradingCommissionSTMBP, "tradingCommissionSTMBP not matched");
        assertEq(s.tradingCommissionMakerBP, result.tradingCommissionMakerBP, "tradingCommissionMakerBP not matched");
    }

    function testSetPremiumCommissionsBasisPoints() public {
        // prettier-ignore
        PolicyCommissionsBasisPoints memory s = PolicyCommissionsBasisPoints({ 
            premiumCommissionNaymsLtdBP: 42, 
            premiumCommissionNDFBP: 42, 
            premiumCommissionSTMBP: 42 
        });

        // must be sys admin
        vm.prank(account9);
        vm.expectRevert("not a system admin");
        nayms.setPolicyCommissionsBasisPoints(s);
        vm.stopPrank();

        nayms.setPolicyCommissionsBasisPoints(s);

        PolicyCommissionsBasisPoints memory result = getPremiumCommissions();

        assertEq(s.premiumCommissionNaymsLtdBP, result.premiumCommissionNaymsLtdBP, "premiumCommissionNaymsLtdBP not matched");
        assertEq(s.premiumCommissionNDFBP, result.premiumCommissionNDFBP, "premiumCommissionNDFBP not matched");
        assertEq(s.premiumCommissionSTMBP, result.premiumCommissionSTMBP, "premiumCommissionSTMBP not matched");
    }

    function getPremiumCommissions() internal returns (PolicyCommissionsBasisPoints memory) {
        (bool success, bytes memory result) = address(nayms).call(abi.encodeWithSelector(libFeeRouterFixture.getPremiumCommissionBasisPointsFixture.selector));
        require(success, "Should get commissions from app storage");
        return abi.decode(result, (PolicyCommissionsBasisPoints));
    }
}
