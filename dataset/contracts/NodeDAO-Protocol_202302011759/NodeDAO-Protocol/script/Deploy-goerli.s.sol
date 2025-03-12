// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "src/oracles/BeaconOracle.sol";
import "src/LiquidStaking.sol";
import "src/tokens/NETH.sol";
import "src/tokens/VNFT.sol";
import "src/registries/NodeOperatorRegistry.sol";
import "src/rewards/ELVault.sol";
import "forge-std/Script.sol";
import "./utils/DeployProxy.sol";

contract DeployGoerliScript is Script {
    address _dao = 0x6aE2F56C057e31a18224DBc6Ae32B0a5FBeDFCB0;
    address _daoValutAddress = 0x6aE2F56C057e31a18224DBc6Ae32B0a5FBeDFCB0;
    address _rewardAddress = 0x6aE2F56C057e31a18224DBc6Ae32B0a5FBeDFCB0;
    address _controllerAddress = 0x6aE2F56C057e31a18224DBc6Ae32B0a5FBeDFCB0;
    address depositContract = 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b;

    LiquidStaking liquidStaking;
    address liquidStakingProxy;

    NETH neth;
    ELVault vaultContract;

    VNFT vnft;
    address vnftProxy;

    NodeOperatorRegistry operatorRegistry;
    address operatorRegistryProxy;

    BeaconOracle beaconOracle;
    address beaconOracleProxy;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        DeployProxy deployer = new DeployProxy();
        deployer.setType("uups");

        neth = new NETH(); // no proxy
        vaultContract = new ELVault(); // no proxy

        vnft = new VNFT();
        operatorRegistry = new NodeOperatorRegistry();
        beaconOracle = new BeaconOracle();
        liquidStaking = new LiquidStaking();

        vnftProxy = deployer.deploy(address(vnft));
        operatorRegistryProxy = deployer.deploy(address(operatorRegistry));
        beaconOracleProxy = deployer.deploy(address(beaconOracle));
        liquidStakingProxy = deployer.deploy(address(liquidStaking));

        // initialize
        VNFT(vnftProxy).initialize();
        vaultContract.initialize(address(vnftProxy), _dao, 1);
        NodeOperatorRegistry(operatorRegistryProxy).initialize(_dao, _daoValutAddress);
        BeaconOracle(beaconOracleProxy).initialize(_dao);
        LiquidStaking(liquidStakingProxy).initialize(
            _dao,
            _daoValutAddress,
            bytes("01"),
            address(operatorRegistryProxy),
            address(neth),
            address(vnftProxy),
            address(beaconOracleProxy),
            address(depositContract)
        );

        // setLiquidStaking
        neth.setLiquidStaking(address(liquidStakingProxy));
        VNFT(vnftProxy).setLiquidStaking(address(liquidStakingProxy));
        vaultContract.setLiquidStaking(address(liquidStakingProxy));

        vm.stopBroadcast();
    }
}
