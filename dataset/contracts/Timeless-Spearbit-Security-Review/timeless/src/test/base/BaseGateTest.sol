// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.4;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";

import {Echo} from "../utils/Echo.sol";
import {BaseTest, console} from "../base/BaseTest.sol";

import {Gate} from "../../Gate.sol";
import {Factory} from "../../Factory.sol";
import {IxPYT} from "../../external/IxPYT.sol";
import {TestXPYT} from "../mocks/TestXPYT.sol";
import {FullMath} from "../../lib/FullMath.sol";
import {TestERC20} from "../mocks/TestERC20.sol";
import {NegativeYieldToken} from "../../NegativeYieldToken.sol";
import {PerpetualYieldToken} from "../../PerpetualYieldToken.sol";

abstract contract BaseGateTest is BaseTest {
    /// -----------------------------------------------------------------------
    /// Global state
    /// -----------------------------------------------------------------------

    Factory internal factory;
    Gate internal gate;
    Echo internal echo;
    address internal constant tester = address(0x69);
    address internal constant tester1 = address(0xabcd);
    address internal constant recipient = address(0xbeef);
    address internal constant nytRecipient = address(0x01);
    address internal constant pytRecipient = address(0x02);
    address internal constant initialDepositor = address(0x420);
    address internal constant protocolFeeRecipient = address(0x6969);
    uint256 internal constant PROTOCOL_FEE = 100; // 10%
    IxPYT internal constant XPYT_NULL = IxPYT(address(0));
    uint256 internal constant PRECISION = 10**27;
    bytes internal constant arithmeticError =
        abi.encodeWithSignature("Panic(uint256)", 0x11);

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier prankAsTester() {
        vm.startPrank(tester);
        _;
        vm.stopPrank();
    }

    /// -----------------------------------------------------------------------
    /// Setup
    /// -----------------------------------------------------------------------

    function setUp() public {
        factory = new Factory(
            address(this),
            Factory.ProtocolFeeInfo({
                fee: uint8(PROTOCOL_FEE),
                recipient: protocolFeeRecipient
            })
        );
        gate = _deployGate();
        echo = new Echo();
    }

    /// -----------------------------------------------------------------------
    /// User action tests
    /// -----------------------------------------------------------------------

    function test_enterWithUnderlying(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 underlyingAmount,
        bool useXPYT
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );
        IxPYT xPYT = useXPYT
            ? new TestXPYT(
                ERC20(address(gate.getPerpetualYieldTokenForVault(vault)))
            )
            : XPYT_NULL;

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        uint256 beforeVaultUnderlyingBalance = underlying.balanceOf(vault);
        uint256 mintAmount = gate.enterWithUnderlying(
            nytRecipient,
            pytRecipient,
            vault,
            xPYT,
            underlyingAmount
        );

        // check balances
        // underlying transferred from tester to vault
        assertEqDecimal(underlying.balanceOf(tester), 0, underlyingDecimals);
        assertEqDecimal(
            underlying.balanceOf(vault) - beforeVaultUnderlyingBalance,
            underlyingAmount,
            underlyingDecimals
        );
        // recipient received NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        assertEqDecimal(
            nyt.balanceOf(nytRecipient),
            underlyingAmount,
            underlyingDecimals
        );
        assertEqDecimal(
            useXPYT
                ? xPYT.balanceOf(pytRecipient)
                : pyt.balanceOf(pytRecipient),
            underlyingAmount,
            underlyingDecimals
        );
        assertEqDecimal(mintAmount, underlyingAmount, underlyingDecimals);
    }

    function test_enterWithVaultShares(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 underlyingAmount,
        bool useXPYT
    ) public {
        vm.assume(gate.vaultSharesIsERC20());

        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );
        IxPYT xPYT = useXPYT
            ? new TestXPYT(
                ERC20(address(gate.getPerpetualYieldTokenForVault(vault)))
            )
            : XPYT_NULL;

        // mint underlying and enter vault
        underlying.mint(address(this), underlyingAmount);
        uint256 vaultSharesAmount = _depositInVault(vault, underlyingAmount);
        // due to the precision limitations of the vault, we might've lost some underlying
        underlyingAmount = uint120(
            _vaultSharesAmountToUnderlyingAmount(vault, vaultSharesAmount)
        );

        // enter
        ERC20(vault).approve(address(gate), type(uint256).max);
        uint256 mintAmount;
        {
            uint256 beforeBalance = ERC20(vault).balanceOf(address(this));
            mintAmount = gate.enterWithVaultShares(
                nytRecipient,
                pytRecipient,
                vault,
                xPYT,
                vaultSharesAmount
            );

            // check balances
            // vault shares transferred from tester to gate
            assertEqDecimal(
                beforeBalance - ERC20(vault).balanceOf(address(this)),
                vaultSharesAmount,
                underlyingDecimals
            );
            assertEqDecimal(
                ERC20(vault).balanceOf(address(gate)),
                vaultSharesAmount,
                underlyingDecimals
            );
        }

        // recipient received NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        uint256 epsilonInv = 10**underlyingDecimals;
        assertEqDecimalEpsilonAround(
            nyt.balanceOf(nytRecipient),
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            useXPYT
                ? xPYT.balanceOf(pytRecipient)
                : pyt.balanceOf(pytRecipient),
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            mintAmount,
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_exitToUnderlying(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        bool useXPYT
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );
        IxPYT xPYT = useXPYT
            ? new TestXPYT(
                ERC20(address(gate.getPerpetualYieldTokenForVault(vault)))
            )
            : XPYT_NULL;

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, tester, vault, xPYT, underlyingAmount);

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);

        // exit
        if (useXPYT) {
            xPYT.approve(address(gate), type(uint256).max);
        }
        uint256 burnAmount;
        {
            bool shouldExpectWithdrawRevert = _shouldExpectExitToUnderlyingRevert(
                    vault,
                    underlyingAmount
                );
            if (shouldExpectWithdrawRevert) {
                vm.expectRevert(arithmeticError);
            }
            burnAmount = gate.exitToUnderlying(
                recipient,
                vault,
                xPYT,
                underlyingAmount
            );
            if (shouldExpectWithdrawRevert) {
                // remaining assertions are pointless
                return;
            }
        }

        // check balances
        uint256 epsilonInv = 10**underlyingDecimals;
        // underlying transferred to tester
        assertEqDecimalEpsilonAround(
            underlying.balanceOf(recipient),
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
        // recipient burnt NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        assertEqDecimalEpsilonAround(
            nyt.balanceOf(recipient),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            useXPYT ? xPYT.balanceOf(recipient) : pyt.balanceOf(recipient),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            burnAmount,
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_exitToVaultShares(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        bool useXPYT
    ) public prankAsTester {
        vm.assume(gate.vaultSharesIsERC20());

        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );
        IxPYT xPYT = useXPYT
            ? new TestXPYT(
                ERC20(address(gate.getPerpetualYieldTokenForVault(vault)))
            )
            : XPYT_NULL;

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(tester, tester, vault, xPYT, underlyingAmount);

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);

        // exit
        if (useXPYT) {
            xPYT.approve(address(gate), type(uint256).max);
        }
        uint256 vaultSharesAmount = _underlyingAmountToVaultSharesAmount(
            vault,
            underlyingAmount
        );
        uint256 burnAmount;
        {
            bool shouldExpectWithdrawRevert = _shouldExpectExitToVaultSharesRevert(
                    vault,
                    vaultSharesAmount
                );
            if (shouldExpectWithdrawRevert) {
                vm.expectRevert(arithmeticError);
            }
            burnAmount = gate.exitToVaultShares(
                recipient,
                vault,
                xPYT,
                vaultSharesAmount
            );
            if (shouldExpectWithdrawRevert) {
                // remaining assertions are pointless
                return;
            }
        }

        // check balances
        uint256 epsilonInv = min(10**(underlyingDecimals - 2), 10**6);
        // vault shares transferred to tester
        assertEqDecimalEpsilonAround(
            ERC20(vault).balanceOf(recipient),
            vaultSharesAmount,
            underlyingDecimals,
            epsilonInv
        );
        // recipient burnt NYT and PYT
        NegativeYieldToken nyt = gate.getNegativeYieldTokenForVault(vault);
        assertEqDecimalEpsilonAround(
            nyt.balanceOf(recipient),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            useXPYT
                ? xPYT.balanceOf(recipient)
                : gate.getPerpetualYieldTokenForVault(vault).balanceOf(
                    recipient
                ),
            0,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            burnAmount,
            underlyingAmount,
            underlyingDecimals,
            epsilonInv
        );
    }

    function testFactory_deployYieldTokenPair(uint8 underlyingDecimals) public {
        // bound between 0 and 18
        underlyingDecimals %= 19;

        TestERC20 underlying = new TestERC20(underlyingDecimals);
        address vault = _deployVault(underlying);
        (NegativeYieldToken nyt, PerpetualYieldToken pyt) = factory
            .deployYieldTokenPair(gate, vault);

        assertEq(
            address(gate.getNegativeYieldTokenForVault(vault)),
            address(nyt)
        );
        assertEq(
            address(gate.getPerpetualYieldTokenForVault(vault)),
            address(pyt)
        );
        assertEq(nyt.name(), _getExpectedNYTName());
        assertEq(pyt.name(), _getExpectedPYTName());
        assertEq(nyt.symbol(), _getExpectedNYTSymbol());
        assertEq(pyt.symbol(), _getExpectedPYTSymbol());
        assertEq(nyt.decimals(), underlyingDecimals);
        assertEq(pyt.decimals(), underlyingDecimals);
        assertEq(nyt.totalSupply(), 0);
        assertEq(pyt.totalSupply(), 0);
    }

    function test_claimYieldInUnderlying(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(vault);
        gate.enterWithUnderlying(
            tester,
            tester,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);
        uint256 afterPricePerVaultShare = gate.getPricePerVaultShare(vault);
        uint256 expectedYield = (FullMath.mulDiv(
            underlyingAmount,
            afterPricePerVaultShare - beforePricePerVaultShare,
            beforePricePerVaultShare
        ) * (1000 - PROTOCOL_FEE)) / 1000;
        uint256 expectedFee = (expectedYield * PROTOCOL_FEE) /
            (1000 - PROTOCOL_FEE);
        if (gate.vaultSharesIsERC20()) {
            // fee paid in vault shares
            expectedFee = _underlyingAmountToVaultSharesAmount(
                vault,
                expectedFee
            );
        }

        // claim yield
        uint256 claimedYield = gate.claimYieldInUnderlying(recipient, vault);

        // check received yield
        uint256 epsilonInv = min(10**(underlyingDecimals - 3), 10**6);
        assertEqDecimalEpsilonAround(
            claimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            underlying.balanceOf(recipient),
            claimedYield,
            underlyingDecimals,
            epsilonInv
        );

        // check protocol fee
        if (gate.vaultSharesIsERC20()) {
            // check vault balance
            assertEqDecimalEpsilonAround(
                ERC20(vault).balanceOf(protocolFeeRecipient),
                expectedFee,
                underlyingDecimals,
                epsilonInv
            );
        } else {
            // check underlying balance
            assertEqDecimalEpsilonAround(
                underlying.balanceOf(protocolFeeRecipient),
                expectedFee,
                underlyingDecimals,
                epsilonInv
            );
        }
    }

    function test_claimYieldInVaultShares(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount
    ) public prankAsTester {
        vm.assume(gate.vaultSharesIsERC20());

        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        uint256 beforePricePerVaultShare = gate.getPricePerVaultShare(vault);
        gate.enterWithUnderlying(
            tester,
            tester,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);
        uint256 afterPricePerVaultShare = gate.getPricePerVaultShare(vault);

        uint256 expectedYield = FullMath.mulDiv(
            underlyingAmount,
            afterPricePerVaultShare - beforePricePerVaultShare,
            beforePricePerVaultShare
        );
        expectedYield =
            (_underlyingAmountToVaultSharesAmount(vault, expectedYield) *
                (1000 - PROTOCOL_FEE)) /
            1000;

        // claim yield
        uint256 claimedYield = gate.claimYieldInVaultShares(recipient, vault);

        // check received yield
        uint256 epsilonInv = min(10**(underlyingDecimals - 3), 10**6);
        console.log(claimedYield, expectedYield);

        assertEqDecimalEpsilonAround(
            claimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            ERC20(vault).balanceOf(recipient),
            claimedYield,
            underlyingDecimals,
            epsilonInv
        );

        // check protocol fee
        uint256 expectedFee = (expectedYield * PROTOCOL_FEE) /
            (1000 - PROTOCOL_FEE);
        assertEqDecimalEpsilonAround(
            ERC20(vault).balanceOf(protocolFeeRecipient),
            expectedFee,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_claimYieldAndEnter(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        bool useXPYT
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        // deploy contracts
        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );
        IxPYT xPYT = useXPYT
            ? new TestXPYT(
                ERC20(address(gate.getPerpetualYieldTokenForVault(vault)))
            )
            : XPYT_NULL;

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        // receive raw PYT
        gate.enterWithUnderlying(
            tester,
            tester,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);
        uint256 expectedYield = gate.getClaimableYieldAmount(vault, tester);
        uint256 expectedFee = (expectedYield * PROTOCOL_FEE) /
            (1000 - PROTOCOL_FEE);
        if (gate.vaultSharesIsERC20()) {
            // fee paid in vault shares
            expectedFee = _underlyingAmountToVaultSharesAmount(
                vault,
                expectedFee
            );
        }

        // claim yield
        uint256 claimedYield = gate.claimYieldAndEnter(
            nytRecipient,
            pytRecipient,
            vault,
            xPYT
        );

        // check received yield
        uint256 epsilonInv = min(10**(underlyingDecimals - 3), 10**6);
        assertEqDecimalEpsilonAround(
            claimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            gate.getNegativeYieldTokenForVault(vault).balanceOf(nytRecipient),
            claimedYield,
            underlyingDecimals,
            epsilonInv
        );
        assertEqDecimalEpsilonAround(
            useXPYT
                ? xPYT.balanceOf(pytRecipient)
                : gate.getPerpetualYieldTokenForVault(vault).balanceOf(
                    pytRecipient
                ),
            claimedYield,
            underlyingDecimals,
            epsilonInv
        );

        // check protocol fee
        if (gate.vaultSharesIsERC20()) {
            // check vault balance
            assertEqDecimalEpsilonAround(
                ERC20(vault).balanceOf(protocolFeeRecipient),
                expectedFee,
                underlyingDecimals,
                epsilonInv
            );
        } else {
            // check underlying balance
            assertEqDecimalEpsilonAround(
                underlying.balanceOf(protocolFeeRecipient),
                expectedFee,
                underlyingDecimals,
                epsilonInv
            );
        }
    }

    function test_transferPYT_toUninitializedAccount(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        uint8 pytTransferPercent
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(
            tester,
            tester,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);
        uint256 expectedYield = gate.getClaimableYieldAmount(vault, tester);

        // transfer PYT to tester1
        gate.getPerpetualYieldTokenForVault(vault).transfer(
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield = gate.claimYieldInUnderlying(
            recipient,
            vault
        );

        // tester should've received all the yield
        uint256 epsilonInv = min(10**(underlyingDecimals - 3), 10**6);
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_transferPYT_toInitializedAccount(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        uint8 pytTransferPercent
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // enter
        underlying.mint(tester, underlyingAmount);
        gate.enterWithUnderlying(
            tester,
            tester,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // switch to tester1
        vm.stopPrank();
        vm.startPrank(tester1);

        // enter
        underlying.mint(tester1, underlyingAmount);
        underlying.approve(address(gate), type(uint256).max);
        gate.enterWithUnderlying(
            tester1,
            tester1,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // switch to tester
        vm.stopPrank();
        vm.startPrank(tester);

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);
        uint256 expectedYield = gate.getClaimableYieldAmount(vault, tester);
        uint256 expectedYield1 = gate.getClaimableYieldAmount(vault, tester1);

        // transfer PYT to tester1
        gate.getPerpetualYieldTokenForVault(vault).transfer(
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        uint256 testerClaimedYield;
        {
            uint256 beforeClaimPricePerVaultShare = gate.getPricePerVaultShare(
                vault
            );
            testerClaimedYield = gate.claimYieldInUnderlying(recipient, vault);
            if (
                beforeClaimPricePerVaultShare !=
                gate.getPricePerVaultShare(vault)
            ) {
                // yield claim caused illusory price change in vault due to rounding
                // can't verify tester1's yield claim amount
                return;
            }
        }

        // tester should've received the correct amount of yield
        uint256 epsilonInv = min(10**(underlyingDecimals - 3), 10**5);
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should've received the correct amount of yield
        vm.stopPrank();
        vm.startPrank(tester1);
        assertEqDecimalEpsilonAround(
            gate.claimYieldInUnderlying(tester1, vault),
            expectedYield1,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_transferFromPYT_toUninitializedAccount(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        uint8 pytTransferPercent
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // mint underlying
        underlying.mint(tester, underlyingAmount);

        // enter
        gate.enterWithUnderlying(
            tester,
            tester,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);
        uint256 expectedYield = gate.getClaimableYieldAmount(vault, tester);

        // give tester1 PYT approval
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        pyt.approve(tester1, type(uint256).max);

        // transfer PYT from tester to tester1, as tester1
        vm.stopPrank();
        vm.prank(tester1);
        pyt.transferFrom(
            tester,
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        vm.startPrank(tester);
        uint256 testerClaimedYield = gate.claimYieldInUnderlying(
            recipient,
            vault
        );

        // tester should've received all the yield
        uint256 epsilonInv = min(10**(underlyingDecimals - 3), 10**6);
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );
    }

    function test_transferFromPYT_toInitializedAccount(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        uint8 pytTransferPercent
    ) public prankAsTester {
        // preprocess arguments
        (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        ) = _preprocessArgs(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );

        // bound between 1 and 99
        pytTransferPercent %= 99;
        pytTransferPercent += 1;

        (TestERC20 underlying, address vault) = _setUpVault(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount
        );

        // enter
        underlying.mint(tester, underlyingAmount);
        gate.enterWithUnderlying(
            tester,
            tester,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // switch to tester1
        vm.stopPrank();
        vm.startPrank(tester1);

        // enter
        underlying.mint(tester1, underlyingAmount);
        underlying.approve(address(gate), type(uint256).max);
        gate.enterWithUnderlying(
            tester1,
            tester1,
            vault,
            XPYT_NULL,
            underlyingAmount
        );

        // switch to tester
        vm.stopPrank();
        vm.startPrank(tester);

        // mint additional yield to the vault
        additionalYieldAmount = _preprocessAdditionalYield(
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            additionalYieldAmount,
            underlyingAmount,
            vault
        );
        underlying.mint(vault, additionalYieldAmount);
        uint256 expectedYield = gate.getClaimableYieldAmount(vault, tester);
        uint256 expectedYield1 = gate.getClaimableYieldAmount(vault, tester1);

        // give tester1 PYT approval
        PerpetualYieldToken pyt = gate.getPerpetualYieldTokenForVault(vault);
        pyt.approve(tester1, type(uint256).max);

        // transfer PYT from tester to tester1, as tester1
        vm.stopPrank();
        vm.prank(tester1);
        pyt.transferFrom(
            tester,
            tester1,
            FullMath.mulDiv(underlyingAmount, pytTransferPercent, 100)
        );

        // claim yield as tester
        vm.startPrank(tester);
        uint256 testerClaimedYield;
        {
            uint256 beforeClaimPricePerVaultShare = gate.getPricePerVaultShare(
                vault
            );
            testerClaimedYield = gate.claimYieldInUnderlying(recipient, vault);
            if (
                beforeClaimPricePerVaultShare !=
                gate.getPricePerVaultShare(vault)
            ) {
                // yield claim caused illusory price change in vault due to rounding
                // can't verify tester1's yield claim amount
                return;
            }
        }

        // tester should've received the correct amount of yield
        uint256 epsilonInv = min(10**(underlyingDecimals - 2), 10**6);
        assertEqDecimalEpsilonAround(
            testerClaimedYield,
            expectedYield,
            underlyingDecimals,
            epsilonInv
        );

        // claim yield as tester1
        // should've received the correct amount of yield
        vm.stopPrank();
        vm.startPrank(tester1);
        assertEqDecimalEpsilonAround(
            gate.claimYieldInUnderlying(tester1, vault),
            expectedYield1,
            underlyingDecimals,
            epsilonInv
        );
    }

    /// -----------------------------------------------------------------------
    /// Failure tests
    /// -----------------------------------------------------------------------

    function testFail_cannotCallPYTTransferHook(
        address from,
        address to,
        uint256 amount,
        uint256 fromAmount,
        uint256 toAmount
    ) public {
        if (amount == 0) amount = 1;
        gate.beforePerpetualYieldTokenTransfer(
            from,
            to,
            amount,
            fromAmount,
            toAmount
        );
    }

    function testFail_cannotDeployTokensTwice(uint8 underlyingDecimals) public {
        TestERC20 underlying = new TestERC20(underlyingDecimals);
        address vault = _deployVault(underlying);
        factory.deployYieldTokenPair(gate, vault);
        factory.deployYieldTokenPair(gate, vault);
    }

    function testFail_cannotSetProtocolFeeAsRando(
        Factory.ProtocolFeeInfo memory protocolFeeInfo_
    ) public prankAsTester {
        factory.ownerSetProtocolFee(protocolFeeInfo_);
    }

    /// -----------------------------------------------------------------------
    /// Owner action tests
    /// -----------------------------------------------------------------------

    function testFactory_ownerSetProtocolFee(
        Factory.ProtocolFeeInfo memory protocolFeeInfo_
    ) public {
        if (
            protocolFeeInfo_.fee != 0 &&
            protocolFeeInfo_.recipient == address(0)
        ) {
            vm.expectRevert(
                abi.encodeWithSignature("Error_ProtocolFeeRecipientIsZero()")
            );
            factory.ownerSetProtocolFee(protocolFeeInfo_);
        } else {
            factory.ownerSetProtocolFee(protocolFeeInfo_);

            (uint8 fee, address recipient_) = factory.protocolFeeInfo();
            assertEq(fee, protocolFeeInfo_.fee);
            assertEq(recipient_, protocolFeeInfo_.recipient);
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal utilities
    /// -----------------------------------------------------------------------

    function _setUpVault(
        uint8 underlyingDecimals,
        uint256 initialUnderlyingAmount,
        uint256 initialYieldAmount
    ) internal returns (TestERC20 underlying, address vault) {
        address prankster = echo.echo();

        // setup contracts
        underlying = new TestERC20(underlyingDecimals);
        vault = _deployVault(underlying);
        underlying.approve(address(gate), type(uint256).max);
        underlying.approve(vault, type(uint256).max);
        factory.deployYieldTokenPair(gate, vault);

        // initialize deposits & yield
        underlying.mint(initialDepositor, initialUnderlyingAmount);
        vm.stopPrank();
        vm.startPrank(initialDepositor);
        underlying.approve(vault, type(uint256).max);
        _depositInVault(vault, initialUnderlyingAmount);
        vm.stopPrank();
        vm.startPrank(prankster);
        underlying.mint(vault, initialYieldAmount);
    }

    function _preprocessArgs(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 underlyingAmount
    )
        internal
        pure
        returns (
            uint8,
            uint120,
            uint120,
            uint120
        )
    {
        // bound between 6 and 18
        underlyingDecimals %= 13;
        underlyingDecimals += 6;

        // ensure underlying amount is large enough
        if (underlyingAmount < 10**underlyingDecimals) {
            underlyingAmount = uint120(10**(underlyingDecimals - 3));
        }

        // ensure initial underlying amount is large enough
        if (initialUnderlyingAmount < 10**underlyingDecimals) {
            initialUnderlyingAmount = uint120(10**(underlyingDecimals - 3));
        }

        // bound the initial yield below 10x the initial underlying
        initialYieldAmount = uint120(
            initialYieldAmount % (uint256(initialUnderlyingAmount) * 10)
        );

        return (
            underlyingDecimals,
            initialUnderlyingAmount,
            initialYieldAmount,
            underlyingAmount
        );
    }

    function _preprocessAdditionalYield(
        uint8 underlyingDecimals,
        uint120 initialUnderlyingAmount,
        uint120 initialYieldAmount,
        uint120 additionalYieldAmount,
        uint120 underlyingAmount,
        address vault
    ) internal view returns (uint120) {
        // the minimum amount of yield the vault can distribute is limited by the precision
        // of its pricePerShare. namely, the yield should be at least the current amount of underlying
        // times (1 / pricePerShare).
        uint256 totalUnderlyingAmount = uint256(underlyingAmount) +
            uint256(initialUnderlyingAmount) +
            uint256(initialYieldAmount);
        additionalYieldAmount = uint120(
            additionalYieldAmount % (totalUnderlyingAmount * 10)
        );
        uint120 minYieldAmount = uint120(
            (totalUnderlyingAmount * 10**(27 - underlyingDecimals + 2)) /
                gate.getPricePerVaultShare(vault)
        );
        if (additionalYieldAmount < minYieldAmount) {
            additionalYieldAmount = minYieldAmount;
        }
        return additionalYieldAmount;
    }

    /// -----------------------------------------------------------------------
    /// Mixins
    /// -----------------------------------------------------------------------

    function _deployGate() internal virtual returns (Gate gate_);

    function _deployVault(ERC20 underlying)
        internal
        virtual
        returns (address vault);

    function _depositInVault(address vault, uint256 underlyingAmount)
        internal
        virtual
        returns (uint256);

    function _getExpectedNYTName() internal virtual returns (string memory);

    function _getExpectedNYTSymbol() internal virtual returns (string memory);

    function _getExpectedPYTName() internal virtual returns (string memory);

    function _getExpectedPYTSymbol() internal virtual returns (string memory);

    function _vaultSharesAmountToUnderlyingAmount(
        address vault,
        uint256 vaultSharesAmount
    ) internal view virtual returns (uint256);

    function _underlyingAmountToVaultSharesAmount(
        address vault,
        uint256 underlyingAmount
    ) internal view virtual returns (uint256);

    function _shouldExpectExitToUnderlyingRevert(
        address vault,
        uint256 underlyingAmount
    ) internal virtual returns (bool);

    function _shouldExpectExitToVaultSharesRevert(
        address vault,
        uint256 vaultSharesAmount
    ) internal virtual returns (bool);
}
