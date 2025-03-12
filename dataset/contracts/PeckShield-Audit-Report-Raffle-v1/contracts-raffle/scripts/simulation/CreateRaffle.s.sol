// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";

// Core contracts
import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";

interface ITestERC721 {
    function mint(address to, uint256 amount) external;

    function setApprovalForAll(address operator, bool approved) external;

    function totalSupply() external returns (uint256);
}

interface ITestERC20 {
    function approve(address operator, uint256 amount) external;

    function mint(address to, uint256 amount) external;
}

contract CreateRaffle is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 chainId = block.chainid;
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        if (chainId != 5 && chainId != 11155111) {
            revert ChainIdInvalid(chainId);
        }

        vm.startBroadcast(deployerPrivateKey);

        Raffle raffle = Raffle(0xb0C8a1a0569F7302d36e380755f1835C3e59aCB9);

        IRaffle.PricingOption[5] memory pricingOptions;
        pricingOptions[0] = IRaffle.PricingOption({entriesCount: 1, price: 0.0000025 ether});
        pricingOptions[1] = IRaffle.PricingOption({entriesCount: 10, price: 0.000022 ether});
        pricingOptions[2] = IRaffle.PricingOption({entriesCount: 25, price: 0.00005 ether});
        pricingOptions[3] = IRaffle.PricingOption({entriesCount: 50, price: 0.000075 ether});
        pricingOptions[4] = IRaffle.PricingOption({entriesCount: 100, price: 0.000095 ether});

        ITestERC721 nft = ITestERC721(0x61AAEcdbe9C2502a72fec63F2Ff510bE1b95DD97);
        uint256 totalSupply = nft.totalSupply();
        nft.mint(0xF332533bF5d0aC462DC8511067A8122b4DcE2B57, 6);
        nft.setApprovalForAll(address(raffle), true);

        ITestERC20 looks = ITestERC20(0xa68c2CaA3D45fa6EBB95aA706c70f49D3356824E);

        uint256 totalPrizeInLooks = 3_000e18;
        looks.mint(0xF332533bF5d0aC462DC8511067A8122b4DcE2B57, totalPrizeInLooks);
        looks.approve(address(raffle), totalPrizeInLooks);

        address[] memory currencies = new address[](1);
        currencies[0] = address(looks);
        raffle.updateCurrenciesStatus(currencies, true);

        IRaffle.Prize[] memory prizes = new IRaffle.Prize[](7);
        for (uint256 i; i < 6; ) {
            if (i != 0) {
                prizes[i].prizeTier = 1;
            }

            prizes[i].prizeType = IRaffle.TokenType.ERC721;
            prizes[i].prizeAddress = address(nft);
            prizes[i].prizeId = totalSupply + i;
            prizes[i].prizeAmount = 1;
            prizes[i].winnersCount = 1;

            unchecked {
                i++;
            }
        }
        prizes[6].prizeTier = 2;
        prizes[6].prizeType = IRaffle.TokenType.ERC20;
        prizes[6].prizeAddress = address(looks);
        prizes[6].prizeAmount = 1_000e18;
        prizes[6].winnersCount = 3;

        uint256 raffleId = raffle.createRaffle(
            IRaffle.CreateRaffleCalldata({
                cutoffTime: uint40(block.timestamp + 5 days),
                isMinimumEntriesFixed: true,
                minimumEntries: 15,
                maximumEntriesPerParticipant: 15,
                protocolFeeBp: 500,
                feeTokenAddress: address(0),
                prizes: prizes,
                pricingOptions: pricingOptions
            })
        );

        raffle.depositPrizes(raffleId);

        vm.stopBroadcast();
    }
}
