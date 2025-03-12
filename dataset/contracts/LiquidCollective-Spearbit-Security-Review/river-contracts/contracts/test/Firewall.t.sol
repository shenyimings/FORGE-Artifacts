//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "./Vm.sol";
import "../src/Firewall.sol";
import "../src/Allowlist.1.sol";
import "../src/River.1.sol";
import "../src/interfaces/IDepositContract.sol";
import "../src/Withdraw.1.sol";
import "../src/Oracle.1.sol";
import "../src/OperatorsRegistry.1.sol";
import "../src/ELFeeRecipient.1.sol";
import "./mocks/DepositContractMock.sol";
import "./mocks/RiverMock.sol";

contract FirewallTests {
    AllowlistV1 internal allowlist;

    ELFeeRecipientV1 internal elFeeRecipient;

    IDepositContract internal deposit;
    WithdrawV1 internal withdraw;
    address internal proxyUpgraderDAO = address(0x484bCd65393c9E835a245Bfa3a299FA02fD1cb18);
    address internal riverGovernorDAO = address(0xEA674fdDe714fd979de3EdF0F56AA9716B898ec8);
    address internal executor = address(0xa22c003A45554Ce90E7F97a3f613F16905440468);
    address internal bob = address(0x34b4424f81AF11f8B8c261b339dd27e1Da796f11);
    address internal joe = address(0xA7206d878c5c3871826DfdB42191c49B1D11F466);
    address internal bobFeeRecipient = address(0x4960b82Ab2fCD4Fa0ab0E52F72C06e95EDCd7360);
    address internal joeFeeRecipient = address(0x892A5d1166C33a3571f01d7F407D678eb4E45805);
    address internal don = address(0xc99b2dBB74607A04B458Ea740F3906C4851C6531);
    address internal treasury = address(0xC88F7666330b4b511358b7742dC2a3234710e7B1);

    RiverV1 internal river;
    OracleV1 internal oracle;
    Firewall internal oracleFirewall;
    OracleV1 internal firewalledOracle;
    IRiverV1 internal oracleInput;

    AllowlistV1 internal firewalledAllowlist;
    Firewall internal allowlistFirewall;

    RiverV1 internal firewalledRiver;
    Firewall internal riverFirewall;

    OperatorsRegistryV1 internal firewalledOperatorsRegistry;
    Firewall internal operatorsRegistryFirewall;

    OperatorsRegistryV1 internal operatorsRegistry;
    uint64 internal constant EPOCHS_PER_FRAME = 225;
    uint64 internal constant SLOTS_PER_EPOCH = 32;
    uint64 internal constant SECONDS_PER_SLOT = 12;
    uint64 internal constant GENESIS_TIME = 1606824023;
    uint256 internal constant UPPER_BOUND = 1000;
    uint256 internal constant LOWER_BOUND = 500;

    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes internal unauthJoe = abi.encodeWithSignature("Unauthorized(address)", joe);
    bytes internal unauthExecutor = abi.encodeWithSignature("Unauthorized(address)", executor);

    function setUp() public {
        deposit = new DepositContractMock();
        elFeeRecipient = new ELFeeRecipientV1();
        withdraw = new WithdrawV1();
        river = new RiverV1();
        allowlist = new AllowlistV1();
        operatorsRegistry = new OperatorsRegistryV1();
        oracle = new OracleV1();

        elFeeRecipient.initELFeeRecipientV1(address(river));

        bytes4[] memory executorCallableAllowlistSelectors = new bytes4[](1);
        executorCallableAllowlistSelectors[0] = allowlist.allow.selector;
        allowlistFirewall = new Firewall(
            riverGovernorDAO,
            executor,
            address(allowlist),
            executorCallableAllowlistSelectors
        );
        firewalledAllowlist = AllowlistV1(payable(address(allowlistFirewall)));
        allowlist.initAllowlistV1(payable(address(allowlistFirewall)), payable(address(allowlistFirewall)));

        bytes4[] memory executorCallableOperatorsRegistrySelectors = new bytes4[](3);
        executorCallableOperatorsRegistrySelectors[0] = operatorsRegistry.setOperatorStatus.selector;
        executorCallableOperatorsRegistrySelectors[1] = operatorsRegistry.setOperatorStoppedValidatorCount.selector;
        executorCallableOperatorsRegistrySelectors[2] = operatorsRegistry.setOperatorLimits.selector;
        operatorsRegistryFirewall = new Firewall(
            riverGovernorDAO,
            executor,
            address(operatorsRegistry),
            executorCallableOperatorsRegistrySelectors
        );
        firewalledOperatorsRegistry = OperatorsRegistryV1(payable(address(operatorsRegistryFirewall)));
        operatorsRegistry.initOperatorsRegistryV1(address(operatorsRegistryFirewall), address(river));

        bytes32 withdrawalCredentials = withdraw.getCredentials();
        bytes4[] memory executorCallableRiverSelectors = new bytes4[](2);
        executorCallableRiverSelectors[0] = river.depositToConsensusLayer.selector;
        executorCallableRiverSelectors[1] = river.setOracle.selector;
        riverFirewall = new Firewall(riverGovernorDAO, executor, address(river), executorCallableRiverSelectors);
        firewalledRiver = RiverV1(payable(address(riverFirewall)));
        river.initRiverV1(
            address(deposit),
            address(elFeeRecipient),
            withdrawalCredentials,
            address(oracle),
            payable(address(riverFirewall)),
            payable(address(allowlist)),
            payable(address(operatorsRegistry)),
            treasury,
            5000,
            50000
        );

        bytes4[] memory executorCallableOracleSelectors = new bytes4[](5);
        executorCallableOracleSelectors[0] = oracle.addMember.selector;
        executorCallableOracleSelectors[1] = oracle.removeMember.selector;
        executorCallableOracleSelectors[2] = oracle.setQuorum.selector;
        executorCallableOracleSelectors[3] = oracle.setBeaconSpec.selector;
        executorCallableOracleSelectors[4] = oracle.setBeaconBounds.selector;
        oracleFirewall = new Firewall(riverGovernorDAO, executor, address(oracle), executorCallableOracleSelectors);
        firewalledOracle = OracleV1(address(oracleFirewall));
        oracleInput = IRiverV1(payable(address(new RiverMock())));
        oracle.initOracleV1(
            address(oracleInput),
            address(oracleFirewall),
            EPOCHS_PER_FRAME,
            SLOTS_PER_EPOCH,
            SECONDS_PER_SLOT,
            GENESIS_TIME,
            UPPER_BOUND,
            LOWER_BOUND
        );
    }

    function testGovernorCanAddOperator() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOperatorsRegistry.addOperator("bob", bob, bobFeeRecipient);
        (int256 _operatorBobIndex,) = operatorsRegistry.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        vm.stopPrank();
    }

    function testExecutorCannotAddOperator() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledOperatorsRegistry.addOperator("joe", joe, joeFeeRecipient);
        vm.stopPrank();
    }

    function testRandomCallerCannotAddOperator() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOperatorsRegistry.addOperator("joe", joe, joeFeeRecipient);
        vm.stopPrank();
    }

    function testGovernorCanSetGlobalFee() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setGlobalFee(5);
        // no assert, just expect no revert - no easy way to check the actual fee value
        vm.stopPrank();
    }

    function testExecutorCannotSetGlobalFee() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledRiver.setGlobalFee(4);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetGlobalFee() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setGlobalFee(3);
        vm.stopPrank();
    }

    function testGovernorCanSetOperatorsRewardShare() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOperatorRewardsShare(5);
        // no assert, just expect no revert - no easy way to check the actual rewards share value
        vm.stopPrank();
    }

    function testExecutorCannotSetOperatorsRewardShare() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        firewalledRiver.setOperatorRewardsShare(4);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorsRewardShare() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOperatorRewardsShare(3);
        vm.stopPrank();
    }

    function testGovernorCanSetAllower() public {
        vm.startPrank(riverGovernorDAO);
        firewalledAllowlist.setAllower(don);
        assert(allowlist.getAllower() == don);
        vm.stopPrank();
    }

    function testExecutorCannotSetAllower() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        allowlist.setAllower(joe);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetAllower() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        allowlist.setAllower(joe);
        vm.stopPrank();
    }

    function haveGovernorAddOperatorBob() public returns (uint256 operatorBobIndex) {
        vm.startPrank(riverGovernorDAO);
        firewalledOperatorsRegistry.addOperator("bob", bob, bobFeeRecipient);
        (int256 _operatorBobIndex,) = operatorsRegistry.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        vm.stopPrank();
        return (uint256(_operatorBobIndex));
    }

    function testGovernorCanSetOperatorStatus() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(riverGovernorDAO);
        firewalledOperatorsRegistry.setOperatorStatus(operatorBobIndex, true);
        assert(operatorsRegistry.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();
    }

    function testExecutorCanSetOperatorStatus() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(executor);
        firewalledOperatorsRegistry.setOperatorStatus(operatorBobIndex, false);
        assert(operatorsRegistry.getOperator(operatorBobIndex).active == false);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorStatus() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOperatorsRegistry.setOperatorStatus(operatorBobIndex, true);
        vm.stopPrank();
    }

    function testGovernorCanSetOperatorStoppedValidatorCount() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        // Assert this by expecting InvalidArgument, NOT Unauthorized
        vm.startPrank(riverGovernorDAO);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        firewalledOperatorsRegistry.setOperatorStoppedValidatorCount(operatorBobIndex, 3);
        vm.stopPrank();
    }

    function testExecutorCanSetOperatorStoppedValidatorCount() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        // Assert this by expecting InvalidArgument, NOT Unauthorized
        vm.startPrank(executor);
        vm.expectRevert(abi.encodeWithSignature("InvalidArgument()"));
        firewalledOperatorsRegistry.setOperatorStoppedValidatorCount(operatorBobIndex, 3);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorStoppedValidatorCount() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOperatorsRegistry.setOperatorStoppedValidatorCount(operatorBobIndex, 3);
        vm.stopPrank();
    }

    function testGovernorCanSetOperatorLimit() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(bob);

        bytes memory tenPublicKeys =
            hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes memory tenSignatures =
            hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsRegistry.addValidators(operatorBobIndex, 10, tenPublicKeys, tenSignatures);
        vm.stopPrank();
        vm.startPrank(riverGovernorDAO);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorBobIndex;
        uint256[] memory operatorLimits = new uint256[](1);
        operatorLimits[0] = 10;
        firewalledOperatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits);
        assert(operatorsRegistry.getOperator(operatorBobIndex).limit == 10);
        vm.stopPrank();
    }

    function testExecutorCanSetOperatorLimit() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(bob);

        bytes memory tenPublicKeys =
            hex"e18e2e0fff999e38c547fb921bd915a1fef6a46e07db2705a57d17542f0acc6be99fee18fb2c17a7f247fc05edd722b9e95f700adf12dd6f20d65c2e411a6a447cb6f4f7c84b8b6673099385d5dcf964e479a9167c802d977ba0a0a22df2336f83182e83bc198c34c301482f189475209fb93d362704e317709fec266f14b3383e7bac3e0e306b1ac8228482c31d7ffbc7e0f865bd4648c7c45c1361f9cd0f4ccab693068a55e6823a4edd8ef4ced9faa64343866ad7357d488bff347a36f2476cc7b4eaf397c832968548ea70e1de2b2691628399d9f59fdd21a62dd3da50d0255790ec1c15949850a869a37595f8f52cc9d681f2b78748254ba36456f7e65d3c7ed2b64ef502cbd3c2f48d789924a99aedfbd097f4ff5829e787ef29b0b79c817337c08ff68c454a1ddc6359d09c0d48a9298a96691c3558812ca13239d9324f146a6b3bfb7bd3f2b1877929ceb74fa1ed590351801935d1e61c875c7772e74d037b26f972f2dfa0569ae9bf8cc32dee87e980497cd79492bf91edeafacfbd6ad32c642a6564ffc9a5d921d0cc35740314c88986547d8f94e60f5d3a2e0a0b1723d20546beaf064adfd78e5f63b600a6ee5b0bacf6f30bf456afadef451a1c503e428fcd295b5d20ad9e065e1684dced5487fd33270bb68b783a6963eab250";
        bytes memory tenSignatures =
            hex"1d40e9c75a57997aa60105f21d0c68c3be0435f1f68f755c33015110e38ef97b4b5e2008096e75b906ae4d1f5aec6ad505920c58758631a06ac8c7666b582c9b3fa70a67e39a5aec2a6a11756eb2c0dd74c33beafce3ce8396e86671e00528c0f4c6e9ccef87d852ac23e38f3a1585b710e4eeaa919b7040e49a55583b250801f4f54a7fc1d514ee4a89f2a0a31b500065ea383c4ff0d2981da1fc7e047239d1743c2ce0412a424fe7d32628d656c57d56a6f322d696b6099f44f5257e051cbfed1497e89d637a05b2063a30f232ceba1677e571b08c3c8bb84979d5fcab1652ae40c0840e29a32725d9b45fea996edce566ffff5be6d38d056c6a1827fb7b0ba69f1923a0384e8da72dced43b0e83714d2eda54916252859962b659e0a081fcb4ea39240afef5b8ae854eb4a159d1bdd9eed58aa368c690fe816052fd3f270215dd0ec0cc55e386ea43cb52849d00cc6a2efbec1d693619f9dcf64bfbc9c1982d1acc877b898f48d8337b372a338907dc7af4d8d58e08e1302313721fef9d9c1697256b3dc113bfc7860bccf01dc4d28d3ef09e43db4ecdd78c41bdc89ed50130b1b87ba137c33928f9aff8481e204d8ccd86938da666357cbf4d7253ce56eed980dc7ec2d4a610f541d8f7c830592bb39b8048848203ce74db2f585a7b8cd1ae6b47192b1983efddfb42c1ad65a0c9ceae3548565829c1bcd1a06da7ed4e10698fd2e5b2715a3cbae861909d8364f622882e080f0a07e153fb29c7c3abcc27f2011e76d09d013a5b511b0de51cbefc206c58cb9c09e405b5db80f1c98ea414ae2705de213715e01b81cda31c4ec814e50b341723dc4be0a81268cd04be2d306347540be98c2a3192a968dbad68ba2b5c066c684d18bdcb7345f1d2b643f2ff7bb8494c093eaaf31ee192c9a1486b387701c3bda0ed55af872665fcb0267e3e0b9e7d55e13555ec0f8742229898693ca26ddbb8cae390e9ec35fc3e07c21236fa8264974f9d3aea67a059d6e88111f48341ffdfa911ad89a2a2fbb2a790d69f3fc7646c0071b0c1ca25567f8e2b09d3177abb3e0ec38e4ebe0da06dd6cd03551682fd7ab3a772f5fbc5cba2afbd17d1ed064cae8db36b6bc6ab33b803a40fc7bc9fc7eb0327ee6486803672f653659cea6cc55212db194b9f7ecf1e0996117a489c5caf861425743681184ed3dbe5f8de71b5e7479ce13b6e1b5f6368b187185e9e14967ec04bb67d3797e4b0b2f00ee0cc61a7e2b2feff0a5ed98d503de0e8e3f445e328e8e8d45dc4453e10f49a6d642cbd90c06d7e81e64cf8d8562f6ef708a5761f1503e221ffa15a5318a880e25f8e3a7e79ce4bd263fdc6f683fb2cd1";

        operatorsRegistry.addValidators(operatorBobIndex, 10, tenPublicKeys, tenSignatures);
        vm.stopPrank();
        vm.startPrank(executor);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorBobIndex;
        uint256[] memory operatorLimits = new uint256[](1);
        operatorLimits[0] = 10;
        firewalledOperatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits);
        assert(operatorsRegistry.getOperator(operatorBobIndex).limit == 10);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOperatorLimit() public {
        uint256 operatorBobIndex = haveGovernorAddOperatorBob();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        uint256[] memory operatorIndexes = new uint256[](1);
        operatorIndexes[0] = operatorBobIndex;
        uint256[] memory operatorLimits = new uint256[](1);
        operatorLimits[0] = 10;
        firewalledOperatorsRegistry.setOperatorLimits(operatorIndexes, operatorLimits);
        vm.stopPrank();
    }

    function testGovernorCanDepositToConsensusLayer() public {
        // Assert this by expecting NotEnoughFunds, NOT Unauthorized
        vm.startPrank(riverGovernorDAO);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
    }

    function testExecutorCanDepositToConsensusLayer() public {
        // Assert this by expecting NotEnoughFunds, NOT Unauthorized
        vm.startPrank(executor);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
    }

    function testRandomCallerCannotDepositToConsensusLayer() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.depositToConsensusLayer(10);
        vm.stopPrank();
    }

    function testGovernorCanSetOracle() public {
        vm.startPrank(riverGovernorDAO);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testExecutorCanSetOracle() public {
        vm.startPrank(executor);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetOracle() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledRiver.setOracle(don);
        vm.stopPrank();
    }

    function testGovernorCanAddMember() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        vm.stopPrank();
    }

    function testGovernorCanRemoveMember() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        firewalledOracle.removeMember(bob);
        assert(!oracle.isMember(bob));
        vm.stopPrank();
    }

    function testExecutorCanAddMember() public {
        vm.startPrank(executor);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        vm.stopPrank();
    }

    function testExecutorCanRemoveMember() public {
        vm.startPrank(executor);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        firewalledOracle.removeMember(bob);
        assert(!oracle.isMember(bob));
        vm.stopPrank();
    }

    function testRandomCallerCannotAddMember() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.addMember(bob);
        vm.stopPrank();
    }

    function testRandomCallerCannotRemoveMember() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.addMember(bob);
        assert(oracle.isMember(bob));
        vm.stopPrank();
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.removeMember(bob);
        vm.stopPrank();
    }

    function testGovernorCanSetQuorum() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setQuorum(2);
        assert(oracle.getQuorum() == 2);
        vm.stopPrank();
    }

    function testExecutorCanSetQuorum() public {
        vm.startPrank(executor);
        firewalledOracle.setQuorum(2);
        assert(oracle.getQuorum() == 2);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetQuorum() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setQuorum(2);
        vm.stopPrank();
    }

    function testGovernorCanSetBeaconSpec() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setBeaconSpec(2, 3, 4, 5);
        assert(oracle.getBeaconSpec().epochsPerFrame == 2);
        vm.stopPrank();
    }

    function testExecutorCanSetBeaconSpec() public {
        vm.startPrank(executor);
        firewalledOracle.setBeaconSpec(2, 3, 4, 5);
        assert(oracle.getBeaconSpec().epochsPerFrame == 2);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetBeaconSpec() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setBeaconSpec(2, 3, 4, 5);
        vm.stopPrank();
    }

    function testGovernorCanSetBeaconBounds() public {
        vm.startPrank(riverGovernorDAO);
        firewalledOracle.setBeaconBounds(2, 3);
        assert(oracle.getBeaconBounds().annualAprUpperBound == 2);
        vm.stopPrank();
    }

    function testExecutorCanSetBeaconBounds() public {
        vm.startPrank(executor);
        firewalledOracle.setBeaconBounds(2, 3);
        assert(oracle.getBeaconBounds().annualAprUpperBound == 2);
        vm.stopPrank();
    }

    function testRandomCallerCannotSetBeaconBounds() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        firewalledOracle.setBeaconBounds(2, 3);
        vm.stopPrank();
    }

    /// @dev convert function sig, of form "functionName(arg1Type,arg2Type)", to the 4 bytes used in
    ///      a contract call, accessible at msg.sig
    function getSelector(string memory functionSig) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(functionSig)));
    }

    function testMakingFunctionGovernorOnly() public {
        // At first, both governor and executor can setOperatorStatus
        vm.startPrank(riverGovernorDAO);
        firewalledOperatorsRegistry.addOperator("bob", bob, bobFeeRecipient);
        (int256 _operatorBobIndex,) = operatorsRegistry.getOperatorDetails("bob");
        assert(_operatorBobIndex >= 0);
        uint256 operatorBobIndex = uint256(_operatorBobIndex);
        firewalledOperatorsRegistry.setOperatorStatus(operatorBobIndex, true);
        assert(operatorsRegistry.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();

        vm.startPrank(executor);
        firewalledOperatorsRegistry.setOperatorStatus(operatorBobIndex, false);
        assert(operatorsRegistry.getOperator(operatorBobIndex).active == false);
        vm.stopPrank();

        // Then we make it governorOnly.
        // Assert governor can still call it, and executor now cannot.
        vm.startPrank(riverGovernorDAO);
        operatorsRegistryFirewall.allowExecutor(getSelector("setOperatorStatus(uint256,bool)"), false);
        firewalledOperatorsRegistry.setOperatorStatus(operatorBobIndex, true);
        assert(operatorsRegistry.getOperator(operatorBobIndex).active == true);
        vm.stopPrank();
        vm.expectRevert(unauthExecutor);
        vm.startPrank(executor);
        firewalledOperatorsRegistry.setOperatorStatus(operatorBobIndex, false);
        vm.stopPrank();
    }

    function testMakingFunctionGovernorOrExecutor() public {
        vm.startPrank(riverGovernorDAO);
        allowlistFirewall.allowExecutor(getSelector("setAllower(address)"), true);
        vm.stopPrank();
        vm.startPrank(executor);
        firewalledAllowlist.setAllower(joe);
        assert(allowlist.getAllower() == joe);
        vm.stopPrank();
    }

    function testExecutorCannotChangePermissions() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        riverFirewall.allowExecutor(getSelector("setGlobalFee(uint256)"), true);
        vm.stopPrank();
    }

    function testRandomCallerCannotChangePermissions() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        riverFirewall.allowExecutor(getSelector("setOperatorStatus(uint256,bool)"), true);
        vm.stopPrank();
    }

    function testGovernorCanChangeGovernor() public {
        // Assert that governor can setGovernor, and the new governor can
        // setAllower, a governorOnly action
        address newGovernorDAO = address(0xdF2a01F10f86A7cdd2EE10cf35B8ab62723096a6);
        vm.startPrank(riverGovernorDAO);
        allowlistFirewall.setGovernor(newGovernorDAO);
        vm.stopPrank();
        vm.startPrank(newGovernorDAO);
        firewalledAllowlist.setAllower(joe);
        assert(allowlist.getAllower() == joe);
        vm.stopPrank();
    }

    function testGovernorCanChangeExecutor() public {
        // Assert that governor can setExecutor and the new executor can
        // setOracle, a governorOrExecutor action
        vm.startPrank(riverGovernorDAO);
        riverFirewall.setExecutor(bob);
        vm.stopPrank();
        vm.startPrank(bob);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testExecutorCanChangeExecutor() public {
        // Assert that executor can setExecutor and the new executor can
        // setOracle, a governorOrExecutor action
        vm.startPrank(executor);
        riverFirewall.setExecutor(joe);
        vm.stopPrank();
        vm.startPrank(joe);
        firewalledRiver.setOracle(don);
        assert(river.getOracle() == don);
        vm.stopPrank();
    }

    function testExecutorCannotChangeGovernor() public {
        vm.startPrank(executor);
        vm.expectRevert(unauthExecutor);
        riverFirewall.setGovernor(don);
        vm.stopPrank();
    }

    function testRandomCallerCannotChangeGovernor() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        riverFirewall.setGovernor(don);
        vm.stopPrank();
    }

    function testRandomCallerCannotChangeExecutor() public {
        vm.startPrank(joe);
        vm.expectRevert(unauthJoe);
        riverFirewall.setExecutor(don);
        vm.stopPrank();
    }
}
