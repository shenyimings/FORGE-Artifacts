pragma solidity 0.8.16;

// SPDX-License-Identifier: BUSL-1.1

import "forge-std/Test.sol";
import "src/utils/interfaces/IRocketStorage.sol";
import "src/utils/interfaces/IRocketNodeStaking.sol";
import "src/utils/interfaces/IRocketNodeDeposit.sol";

abstract contract RocketPoolHelperContract is Test {
    uint256 rplStakeAsPerTx = 84061696117349943401;

    address blockscapeRocketPoolNode =
        0xF6132f532ABc3902EA2DcaE7f8D7FCCdF7Ba4982;

    RocketStorageInterface constant rocketStorage =
        RocketStorageInterface(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46); // mainnet: 0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46

    address rocketNodeStakingAddress =
        rocketStorage.getAddress(
            keccak256(abi.encodePacked("contract.address", "rocketNodeStaking"))
        );

    RocketNodeStakingInterface rocketNodeStaking =
        RocketNodeStakingInterface(rocketNodeStakingAddress);

        RocketNodeStakingInterface rocketNodeStaking2 =
        RocketNodeStakingInterface(0xca317A4ecCbe0Dd5832dE2A7407e3c03F88b2CdD);

    RocketNodeDepositInterface rocketNodeDeposit =
        RocketNodeDepositInterface(0xB467959ADFc3fA8d99470eC12F4c95aa4D9b59e5);

    function _blockscapeStakeRPL() internal {
        vm.startPrank(blockscapeRocketPoolNode);

        // https://etherscan.io/tx/0x944093ca45dd60ea392a7a28afa14c76f0341535f66184f178dbafb19bac6fc3
        rocketNodeStaking.stakeRPL(rplStakeAsPerTx);

        // https://etherscan.io/tx/0x262befd5cd4b1ec508be35c73caea34b3c18c375cd81cc80bd70c5e4f024b628
        rocketStorage.setWithdrawalAddress(
            address(blockscapeRocketPoolNode),
            0x7248f119fEa1dc252084dfDBa285C67Db3fD40A3,
            false
        );

        vm.stopPrank();
        _warpTimeAfterRPLStake();
    }

    function _blockscapeStakeRPLOtherNode() internal {
        vm.startPrank(blockscapeRocketPoolNode);

        // https://etherscan.io/tx/0x944093ca45dd60ea392a7a28afa14c76f0341535f66184f178dbafb19bac6fc3
        rocketNodeStaking2.stakeRPL(rplStakeAsPerTx);

        // https://etherscan.io/tx/0x262befd5cd4b1ec508be35c73caea34b3c18c375cd81cc80bd70c5e4f024b628
        rocketStorage.setWithdrawalAddress(
            address(blockscapeRocketPoolNode),
            0x7248f119fEa1dc252084dfDBa285C67Db3fD40A3,
            false
        );

        vm.stopPrank();
        _warpTimeAfterRPLStake();
    }

    function _blockscapeUnstakeRPL() internal {
        vm.prank(blockscapeRocketPoolNode);
        rocketNodeStaking.withdrawRPL(rplStakeAsPerTx);
    }

    function _warpTimeAfterRPLStake() internal {
        // timestamp of block 16376810
        // new Date("Jan 10 2023 01:48:59 PM +UTC").getTime() / 1000
        vm.warp(1673358539);
        vm.roll(16376810);
    }

    function _warpTimeToDeposit() internal {
        vm.warp(1673362787);
        vm.roll(16377160);
    }

    function _warpAfterStakingCooldown() internal {
        vm.warp(block.timestamp + 33 days);
    }

    // unused for now as the depositing function reverts
    // function _depositToRocketpool() internal {
    //     uint256 _minimumNodeFee = 150000000000000000;
    //     bytes
    //         memory _validatorPubkey = hex"a2e78385831894094502727373588fc1794ea2800b2b6e614358fea78dcf0cc4d103008a53c665f294e31af0397253e3";
    //     bytes
    //         memory _validatorSignature = hex"b666dc93c0c512272fa38bd027753a502d30fce1692dd898a04c8bd34e013dd5b6cd32e1148b5fb67d6e33da04225cf1144ef93cdd4c9fab154fac150d1ad8ae0cb1a5b80753fb5f1416b19dd1d91f111b6a294208fda8c36e1ec1e82a946641";
    //     bytes32 _depositDataRoot = 0xe06245a3a3593024d64fd679e7ae191adaa951452cec5b72231d66a1d7e48302;
    //     uint256 _salt = 35946;
    //     address _expectedMinipoolAddress = 0x626CA3f82a4A11C2226101eeEA35Fcc25a5fE91D;

    //     _warpTimeToDeposit();

    //     vm.prank(blockscapeRocketPoolNode);
    //     // https://etherscan.io/tx/0x29b03b5c73f3221a996987d7eeffa1f83e04b7e9b4cebc692e6bffa7804c382c
    //     rocketNodeDeposit.deposit{value: curETHlimit}(
    //         _minimumNodeFee,
    //         _validatorPubkey,
    //         _validatorSignature,
    //         _depositDataRoot,
    //         _salt,
    //         _expectedMinipoolAddress
    //     );
    // }
}
