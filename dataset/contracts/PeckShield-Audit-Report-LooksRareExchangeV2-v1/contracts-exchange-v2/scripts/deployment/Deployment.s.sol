// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";

// Core contracts
import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {StrategyCollectionOffer} from "../../contracts/executionStrategies/StrategyCollectionOffer.sol";

// Create2 factory interface
import {IImmutableCreate2Factory} from "../../contracts/interfaces/IImmutableCreate2Factory.sol";

// Other contracts
import {OrderValidatorV2A} from "../../contracts/helpers/OrderValidatorV2A.sol";

contract Deployment is Script {
    IImmutableCreate2Factory private constant IMMUTABLE_CREATE2_FACTORY =
        IImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

    error ChainIdInvalid(uint256 chainId);

    address public weth;

    // address public royaltyFeeRegistry;

    uint16 internal constant _standardProtocolFeeBp = uint16(50);
    uint16 internal constant _minTotalFeeBp = uint16(50);
    uint16 internal constant _maxProtocolFeeBp = uint16(200);

    function run() external {
        uint256 chainId = block.chainid;
        uint256 deployerPrivateKey;

        if (chainId == 1) {
            weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            // royaltyFeeRegistry = 0x55010472a93921a117aAD9b055c141060c8d8022;
            deployerPrivateKey = vm.envUint("MAINNET_KEY");
        } else if (chainId == 5) {
            weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
            // royaltyFeeRegistry = 0x12405dB79325D06a973aD913D6e9BdA1343cD526;
            deployerPrivateKey = vm.envUint("TESTNET_KEY");
        } else if (chainId == 11155111) {
            weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
            deployerPrivateKey = vm.envUint("TESTNET_KEY");
        } else {
            revert ChainIdInvalid(chainId);
        }

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy TransferManager
        address transferManagerAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2({
            salt: vm.envBytes32("TRANSFER_MANAGER_SALT"),
            initializationCode: abi.encodePacked(
                type(TransferManager).creationCode,
                abi.encode(vm.envAddress("OWNER_ADDRESS"))
            )
        });

        // 2. Transfer 1 wei to LooksRareProtocol before it is deployed.
        //    It cannot receive ETH after it is deployed.
        payable(0x0000000000E655fAe4d56241588680F86E3b2377).transfer(1 wei);

        // 3. Deploy LooksRareProtocol
        address looksRareProtocolAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2({
            salt: vm.envBytes32("LOOKSRARE_PROTOCOL_SALT"),
            initializationCode: abi.encodePacked(
                type(LooksRareProtocol).creationCode,
                abi.encode(
                    vm.envAddress("OWNER_ADDRESS"),
                    vm.envAddress("PROTOCOL_FEE_RECIPIENT_ADDRESS"),
                    transferManagerAddress,
                    weth
                )
            )
        });

        // 4. Other operations
        TransferManager(transferManagerAddress).allowOperator(looksRareProtocolAddress);
        LooksRareProtocol(looksRareProtocolAddress).updateCurrencyStatus(address(0), true);
        LooksRareProtocol(looksRareProtocolAddress).updateCurrencyStatus(weth, true);

        // 5. Deploy OrderValidatorV2A, this needs to happen after updateCreatorFeeManager
        //    as the order validator calls creator fee manager to retrieve the royalty fee registry
        new OrderValidatorV2A(looksRareProtocolAddress);

        // 6. Deploy StrategyCollectionOffer
        address strategyCollectionOfferAddress = IMMUTABLE_CREATE2_FACTORY.safeCreate2({
            salt: vm.envBytes32("STRATEGY_COLLECTION_OFFER_SALT"),
            initializationCode: type(StrategyCollectionOffer).creationCode
        });

        LooksRareProtocol(looksRareProtocolAddress).addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            StrategyCollectionOffer.executeCollectionStrategyWithTakerAsk.selector,
            true,
            strategyCollectionOfferAddress
        );

        LooksRareProtocol(looksRareProtocolAddress).addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            StrategyCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector,
            true,
            strategyCollectionOfferAddress
        );

        vm.stopBroadcast();
    }
}
