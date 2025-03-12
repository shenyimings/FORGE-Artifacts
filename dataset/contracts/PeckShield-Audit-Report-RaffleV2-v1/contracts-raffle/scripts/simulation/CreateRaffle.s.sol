// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";
import "forge-std/console2.sol";
import {SimulationBase} from "./SimulationBase.sol";

// Core contracts
import {RaffleV2} from "../../contracts/RaffleV2.sol";
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

interface ITestERC721 {
    function mint(address to, uint256 amount) external;

    function setApprovalForAll(address operator, bool approved) external;

    function totalSupply() external returns (uint256);
}

interface ITestERC20 {
    function approve(address operator, uint256 amount) external;

    function mint(address to, uint256 amount) external;
}

contract CreateRaffle is Script, SimulationBase {
    function run() external {
        uint256 chainId = block.chainid;
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        vm.startBroadcast(deployerPrivateKey);

        IRaffleV2 raffle = getRaffle(chainId);

        IRaffleV2.PricingOption[] memory pricingOptions = new IRaffleV2.PricingOption[](5);
        pricingOptions[0] = IRaffleV2.PricingOption({entriesCount: 1, price: 0.0000025 ether});
        pricingOptions[1] = IRaffleV2.PricingOption({entriesCount: 10, price: 0.000022 ether});
        pricingOptions[2] = IRaffleV2.PricingOption({entriesCount: 25, price: 0.00005 ether});
        pricingOptions[3] = IRaffleV2.PricingOption({entriesCount: 50, price: 0.000075 ether});
        pricingOptions[4] = IRaffleV2.PricingOption({entriesCount: 100, price: 0.000095 ether});

        ITestERC721 nft = ITestERC721(getERC721(chainId));
        uint256 totalSupply = nft.totalSupply();
        nft.mint(RAFFLE_OWNER, 1);
        // nft.setApprovalForAll(getTransferManager(chainId), true);

        ITestERC721 nftB = ITestERC721(getERC721B(chainId));
        uint256 totalSupplyB = nftB.totalSupply();
        nftB.mint(RAFFLE_OWNER, 10);
        // nftB.setApprovalForAll(getTransferManager(chainId), true);

        ITestERC20 looks = ITestERC20(getERC20(chainId));

        uint256 totalPrizeInLooks = 3 ether;
        if (chainId == 11155111) {
            looks.mint(RAFFLE_OWNER, totalPrizeInLooks);
        }
        looks.approve(getTransferManager(chainId), totalPrizeInLooks);

        // address[] memory currencies = new address[](1);
        // currencies[0] = address(looks);
        // raffle.updateCurrenciesStatus(currencies, true);

        IRaffleV2.Prize[] memory prizes = new IRaffleV2.Prize[](7);

        prizes[0].prizeTier = 0;
        prizes[0].prizeType = IRaffleV2.TokenType.ERC721;
        prizes[0].prizeAddress = address(nft);
        prizes[0].prizeId = totalSupply;
        prizes[0].prizeAmount = 1;
        prizes[0].winnersCount = 1;

        for (uint256 i = 1; i < 6; ) {
            prizes[i].prizeTier = 1;
            prizes[i].prizeType = IRaffleV2.TokenType.ERC721;
            prizes[i].prizeAddress = address(nftB);
            prizes[i].prizeId = totalSupplyB + (i - 1);
            prizes[i].prizeAmount = 1;
            prizes[i].winnersCount = 1;

            unchecked {
                i++;
            }
        }
        prizes[6].prizeTier = 2;
        prizes[6].prizeType = IRaffleV2.TokenType.ERC20;
        prizes[6].prizeAddress = address(looks);
        prizes[6].prizeAmount = 1 ether;
        prizes[6].winnersCount = 3;

        raffle.createRaffle(
            IRaffleV2.CreateRaffleCalldata({
                cutoffTime: uint40(block.timestamp + 5 days),
                isMinimumEntriesFixed: true,
                minimumEntries: 15,
                maximumEntriesPerParticipant: 15,
                protocolFeeBp: 0,
                feeTokenAddress: address(0),
                prizes: prizes,
                pricingOptions: pricingOptions
            })
        );

        vm.stopBroadcast();
    }
}
