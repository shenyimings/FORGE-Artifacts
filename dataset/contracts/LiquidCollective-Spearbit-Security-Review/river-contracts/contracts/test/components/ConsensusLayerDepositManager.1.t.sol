//SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "../Vm.sol";
import "../../src/components/ConsensusLayerDepositManager.1.sol";
import "../../src/libraries/UnstructuredStorage.sol";
import "../utils/UserFactory.sol";
import "../mocks/DepositContractMock.sol";

contract ConsensusLayerDepositManagerV1ExposeInitializer is ConsensusLayerDepositManagerV1 {
    function publicConsensusLayerDepositManagerInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials
    )
        external
    {
        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
    }

    bytes public _publicKeys =
        hex"746ce769697901e86d4fb795527393e974d182e8ac03e6ea6c8bb3e0f4458e9196a87915affcc77c543e302e743fa15f65ecc7e935467d39f1296d8a5bd693ce87248f969b36d3f226f573d28a42bbcd4d27fe4399e60e9a55565391df1210c5d472643c683a63ae1e8d2796e52cb209dcf58188bb4d26fb9ede7a49d2737af9d32081497a0edd12aaf815157736c50814fdffbfb1fb51d4c5a4db9a2ff8222f036347e6046eb85c9e04bbcea922261694118aa4714685ffff83cbf3f74cabe2a01f8b1924045e9aceeba071cb46efc0ee3ff3ecd2eac6ecdd8d0bdbb660eabe30a695d887b6b5a138012ca0fcc40f652a6401c91102088769ef0df4f17874a8d2c832dc5371c6350b94fd637f6b7eba1f3aefea815460dd1bb56d41339a39bb977ca9018a56ee20ad09defcd184c3a9988bdbe0ca19da2d39e8ecd5aa4e7f1a81b3d9145ecd7a19317379c10edc875f345f4ccd905440a57986ea3e981804a3bfcd72c64faa543e3b7d1bc1eddb03df6576afec37e4cd04fb928d4039e8e7495e92efaa2cb7dcbb3e817f771b6fc0d6ce8db7cbed38bf6fabd198cd2b7184d7b737c1c05f1d1a10d8e8141b875f1d2c4681ddeb7bad423182704048f3fb9fe82bded37429b0643af12c730b0f0851815a6ef1a563fdcef7c05512b33278218c";
    bytes public _signatures =
        hex"6e93b287f9972d6e4bb7b9b7bdf75e2f3190b61dff0699d9708ee2a6e08f0ce1436b3f0213c1d7e0168cd1b221326b917e0dba509208bf586923ccc53e30b9bc697834508a4c54cd4f097f2c8c5d1b7b3c829fdc326f8df92aae75f008099e1e0324e6ea8734ab375bc33000ab02c63423c3dec20823ac27cadc1e393fa1f15774e52c6a5194dd9136f253b1dc8e0cf9f1a9eec02517d923af4f242e2215d4f82d2bfb657e666f24e5c5f8e6c9636250c0e8f2c20ddd91eda71d1ef5896dbc0fd84508f71958ab19b047030cee1911d55194e38051111021e0710e0be25c3f878ba11c7db118b06a6fc04570cba519c1aa4184693f024bc0e02019dfb62dacab8a2b1127d1b03645ed6377717cbd099aab8d6a5bef2be1aa8e0bb7e2565c8eddfa91b72ae014adb0a47a272d1aedd5920a2ec2f788fe76852b45961d959fdb627329326352f8f3e73bb758022265174af7bc6e3b8ef19f173244735f68789d0f6a34de6da1e22142478205388e8b9db291e01227aa5e4e7173aa11624341b31a202ffade6b5418099dd583708c1fb95525bbfa87b1d08455b640ce25cf322b00471f8dc813dbcd8b82c20e9d07c6215e86237d94ed6f81c7a7ffce0180c128be4f036203e9acfa713d41609a654de0a56a1689da6dcd3950dfd1e3f36987cca569ba947c97b205e34f8ed2dd87b4e29a822676457121ff48ee8bb4dd0b7200093883f6cde4edf1026abc5bc5692dbbfb2197fb4cfbac4eecc99b7956a4dab19cc74db50cf83ff35e880ef58457d3a5b444a17c072ea617ff28cf7bba2657f8ef118a8e6f65453548aafea8c8b88a0df7dbeeaecff69d05ff0dfc55fb97eb94b05b7d7aa748f5aaf6fe38aa6183f400d65e0152004780a089449a5bd77e04b7bd0682c67f5c4fd12bf56b6b31ec3eccfe104f8f64c8b9d23375e0078ba8fe6253037a8a2171682301d5463ce24b4e920af83fd009b6214450382309a143332e8dfa05a95dfa686a630b95b80cfd9b42d33cc3de7f5708dd67714192a14ca814a1f3cc4b4932c36831674ee8ba3a58f12643c1b4bf1e00370290ac4d5e994410d69bad8c691efaf5b6e8fe8331882f7dc304d8ccb6bd9d6079c1698dbdef47996c937046157498db082443ddd33f61e1abb204f12d553b25ea1d773812f701a3c9b36c5909c3b9ebd18d2ba1b8a2daeae36a2811a59bbae1d334fde54e07eac5770172c36d50d821fb181c97bb00a9684a904a2fc8c9c520e730fca4751b4f0d266dc33ddbb7e8ea065ccc47a7dbea61a185ab2413917a039e505e85e2f781eeef96658b94a07f9662ff3e6c8728de755c7a305f975ae8772c8b75468ad30a5467";

    function _getNextValidators(uint256 _amount) internal view override returns (bytes[] memory, bytes[] memory) {
        uint256 amount = _amount > 10 ? 10 : _amount;
        bytes[] memory publicKeys = new bytes[](amount);
        bytes[] memory signatures = new bytes[](amount);

        for (uint256 idx = 0; idx < amount; ++idx) {
            publicKeys[idx] = BytesLib.slice(_publicKeys, idx * 48, 48);
            signatures[idx] = BytesLib.slice(_signatures, idx * 96, 96);
        }

        return (publicKeys, signatures);
    }

    function sudoSetWithdrawalCredentials(bytes32 _withdrawalCredentials) external {
        WithdrawalCredentials.set(_withdrawalCredentials);
    }
}

contract ConsensusLayerDepositManagerV1Tests {
    event FundedValidatorKey(bytes publicKey);

    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    function setUp() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ExposeInitializer();
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testRetrieveWithdrawalCredentials() public view {
        assert(depositManager.getWithdrawalCredentials() == withdrawalCredentials);
    }

    function testDepositNotEnoughFunds() public {
        vm.deal(address(depositManager), 31.9 ether);
        vm.expectRevert(abi.encodeWithSignature("NotEnoughFunds()"));
        depositManager.depositToConsensusLayer(5);
    }

    function testDepositTenValidators() public {
        vm.deal(address(depositManager), 320 ether);
        assert(address(depositManager).balance == 320 ether);
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKey(
            hex"4681ddeb7bad423182704048f3fb9fe82bded37429b0643af12c730b0f0851815a6ef1a563fdcef7c05512b33278218c"
            );
        depositManager.depositToConsensusLayer(10);
        assert(address(depositManager).balance == 0);
    }

    function testDepositTwentyValidators() public {
        vm.deal(address(depositManager), 640 ether);
        assert(address(depositManager).balance == 640 ether);
        vm.expectEmit(true, true, true, true);
        emit FundedValidatorKey(
            hex"4681ddeb7bad423182704048f3fb9fe82bded37429b0643af12c730b0f0851815a6ef1a563fdcef7c05512b33278218c"
            );
        depositManager.depositToConsensusLayer(20);
        assert(address(depositManager).balance == 320 ether);
    }
}

contract ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest is ConsensusLayerDepositManagerV1 {
    function publicConsensusLayerDepositManagerInitializeV1(
        address _depositContractAddress,
        bytes32 _withdrawalCredentials
    )
        external
    {
        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
    }

    bytes public _publicKeys =
        hex"746ce769697901e86d4fb795527393e974d182e8ac03e6ea6c8bb3e0f4458e9196a87915affcc77c543e302e743fa15f65ecc7e935467d39f1296d8a5bd693ce87248f969b36d3f226f573d28a42bbcd4d27fe4399e60e9a55565391df1210c5d472643c683a63ae1e8d2796e52cb209dcf58188bb4d26fb9ede7a49d2737af9d32081497a0edd12aaf815157736c50814fdffbfb1fb51d4c5a4db9a2ff8222f036347e6046eb85c9e04bbcea922261694118aa4714685ffff83cbf3f74cabe2a01f8b1924045e9aceeba071cb46efc0ee3ff3ecd2eac6ecdd8d0bdbb660eabe30a695d887b6b5a138012ca0fcc40f652a6401c91102088769ef0df4f17874a8d2c832dc5371c6350b94fd637f6b7eba1f3aefea815460dd1bb56d41339a39bb977ca9018a56ee20ad09defcd184c3a9988bdbe0ca19da2d39e8ecd5aa4e7f1a81b3d9145ecd7a19317379c10edc875f345f4ccd905440a57986ea3e981804a3bfcd72c64faa543e3b7d1bc1eddb03df6576afec37e4cd04fb928d4039e8e7495e92efaa2cb7dcbb3e817f771b6fc0d6ce8db7cbed38bf6fabd198cd2b7184d7b737c1c05f1d1a10d8e8141b875f1d2c4681ddeb7bad423182704048f3fb9fe82bded37429b0643af12c730b0f0851815a6ef1a563fdcef7c05512b33278218c";
    bytes public _signatures =
        hex"6e93b287f9972d6e4bb7b9b7bdf75e2f3190b61dff0699d9708ee2a6e08f0ce1436b3f0213c1d7e0168cd1b221326b917e0dba509208bf586923ccc53e30b9bc697834508a4c54cd4f097f2c8c5d1b7b3c829fdc326f8df92aae75f008099e1e0324e6ea8734ab375bc33000ab02c63423c3dec20823ac27cadc1e393fa1f15774e52c6a5194dd9136f253b1dc8e0cf9f1a9eec02517d923af4f242e2215d4f82d2bfb657e666f24e5c5f8e6c9636250c0e8f2c20ddd91eda71d1ef5896dbc0fd84508f71958ab19b047030cee1911d55194e38051111021e0710e0be25c3f878ba11c7db118b06a6fc04570cba519c1aa4184693f024bc0e02019dfb62dacab8a2b1127d1b03645ed6377717cbd099aab8d6a5bef2be1aa8e0bb7e2565c8eddfa91b72ae014adb0a47a272d1aedd5920a2ec2f788fe76852b45961d959fdb627329326352f8f3e73bb758022265174af7bc6e3b8ef19f173244735f68789d0f6a34de6da1e22142478205388e8b9db291e01227aa5e4e7173aa11624341b31a202ffade6b5418099dd583708c1fb95525bbfa87b1d08455b640ce25cf322b00471f8dc813dbcd8b82c20e9d07c6215e86237d94ed6f81c7a7ffce0180c128be4f036203e9acfa713d41609a654de0a56a1689da6dcd3950dfd1e3f36987cca569ba947c97b205e34f8ed2dd87b4e29a822676457121ff48ee8bb4dd0b7200093883f6cde4edf1026abc5bc5692dbbfb2197fb4cfbac4eecc99b7956a4dab19cc74db50cf83ff35e880ef58457d3a5b444a17c072ea617ff28cf7bba2657f8ef118a8e6f65453548aafea8c8b88a0df7dbeeaecff69d05ff0dfc55fb97eb94b05b7d7aa748f5aaf6fe38aa6183f400d65e0152004780a089449a5bd77e04b7bd0682c67f5c4fd12bf56b6b31ec3eccfe104f8f64c8b9d23375e0078ba8fe6253037a8a2171682301d5463ce24b4e920af83fd009b6214450382309a143332e8dfa05a95dfa686a630b95b80cfd9b42d33cc3de7f5708dd67714192a14ca814a1f3cc4b4932c36831674ee8ba3a58f12643c1b4bf1e00370290ac4d5e994410d69bad8c691efaf5b6e8fe8331882f7dc304d8ccb6bd9d6079c1698dbdef47996c937046157498db082443ddd33f61e1abb204f12d553b25ea1d773812f701a3c9b36c5909c3b9ebd18d2ba1b8a2daeae36a2811a59bbae1d334fde54e07eac5770172c36d50d821fb181c97bb00a9684a904a2fc8c9c520e730fca4751b4f0d266dc33ddbb7e8ea065ccc47a7dbea61a185ab2413917a039e505e85e2f781eeef96658b94a07f9662ff3e6c8728de755c7a305f975ae8772c8b75468ad30a5467";

    uint256 public scenario;

    function setScenario(uint256 _newScenario) external {
        scenario = _newScenario;
    }

    function _getNextValidators(uint256 _amount) internal view override returns (bytes[] memory, bytes[] memory) {
        if (scenario == 0) {
            uint256 amount = _amount > 10 ? 10 : _amount;
            bytes[] memory publicKeys = new bytes[](amount);
            bytes[] memory signatures = new bytes[](amount);

            for (uint256 idx = 0; idx < amount; ++idx) {
                publicKeys[idx] = BytesLib.slice(_publicKeys, idx * 48, 48);
                signatures[idx] = BytesLib.slice(_signatures, idx * 96, 96);
            }

            return (publicKeys, signatures);
        } else if (scenario == 1) {
            // invalid public key length
            bytes[] memory publicKeys = new bytes[](1);
            bytes[] memory signatures = new bytes[](1);

            publicKeys[0] = BytesLib.slice(_publicKeys, 0, 49);
            signatures[0] = BytesLib.slice(_signatures, 0, 96);
            return (publicKeys, signatures);
        } else if (scenario == 2) {
            // invalid signature length
            bytes[] memory publicKeys = new bytes[](1);
            bytes[] memory signatures = new bytes[](1);

            publicKeys[0] = BytesLib.slice(_publicKeys, 0, 48);
            signatures[0] = BytesLib.slice(_signatures, 0, 97);
            return (publicKeys, signatures);
        } else if (scenario == 3) {
            // no keys available
            bytes[] memory publicKeys = new bytes[](0);
            bytes[] memory signatures = new bytes[](0);

            return (publicKeys, signatures);
        } else if (scenario == 4) {
            // return 2 key sets
            bytes[] memory publicKeys = new bytes[](2);
            bytes[] memory signatures = new bytes[](2);

            publicKeys[0] = BytesLib.slice(_publicKeys, 0, 48);
            signatures[0] = BytesLib.slice(_signatures, 0, 96);
            publicKeys[1] = BytesLib.slice(_publicKeys, 48, 48);
            signatures[1] = BytesLib.slice(_signatures, 96, 96);
            return (publicKeys, signatures);
        } else if (scenario == 5) {
            // 1 public key but 2 signatures
            bytes[] memory publicKeys = new bytes[](1);
            bytes[] memory signatures = new bytes[](2);

            publicKeys[0] = BytesLib.slice(_publicKeys, 0, 48);
            signatures[0] = BytesLib.slice(_signatures, 0, 96);
            signatures[1] = BytesLib.slice(_signatures, 96, 96);
            return (publicKeys, signatures);
        }
        return (new bytes[](0), new bytes[](0));
    }

    function sudoSetWithdrawalCredentials(bytes32 _withdrawalCredentials) external {
        WithdrawalCredentials.set(_withdrawalCredentials);
    }
}

contract ConsensusLayerDepositManagerV1ErrorTests {
    Vm internal vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    bytes32 internal withdrawalCredentials = bytes32(uint256(1));

    ConsensusLayerDepositManagerV1 internal depositManager;
    IDepositContract internal depositContract;

    function setUp() public {
        depositContract = new DepositContractMock();

        depositManager = new ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest();
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager))
            .publicConsensusLayerDepositManagerInitializeV1(address(depositContract), withdrawalCredentials);
    }

    function testInconsistentPublicKey() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).setScenario(1);
        vm.expectRevert(abi.encodeWithSignature("InconsistentPublicKeys()"));
        depositManager.depositToConsensusLayer(5);
    }

    function testInconsistentSignature() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).setScenario(2);
        vm.expectRevert(abi.encodeWithSignature("InconsistentSignatures()"));
        depositManager.depositToConsensusLayer(5);
    }

    function testUnavailableKeys() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).setScenario(3);
        vm.expectRevert(abi.encodeWithSignature("NoAvailableValidatorKeys()"));
        depositManager.depositToConsensusLayer(5);
    }

    function testInvalidPublicKeyCount() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).setScenario(4);
        vm.expectRevert(abi.encodeWithSignature("InvalidPublicKeyCount()"));
        depositManager.depositToConsensusLayer(5);
    }

    function testInvalidSignatureCount() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).setScenario(5);
        vm.expectRevert(abi.encodeWithSignature("InvalidSignatureCount()"));
        depositManager.depositToConsensusLayer(5);
    }

    function testInvalidWithdrawalCredential() public {
        vm.deal(address(depositManager), 32 ether);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager)).setScenario(0);
        ConsensusLayerDepositManagerV1ControllableValidatorKeyRequest(address(depositManager))
            .sudoSetWithdrawalCredentials(bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("InvalidWithdrawalCredentials()"));
        depositManager.depositToConsensusLayer(5);
        ConsensusLayerDepositManagerV1ExposeInitializer(address(depositManager)).sudoSetWithdrawalCredentials(
            withdrawalCredentials
        );
    }
}
