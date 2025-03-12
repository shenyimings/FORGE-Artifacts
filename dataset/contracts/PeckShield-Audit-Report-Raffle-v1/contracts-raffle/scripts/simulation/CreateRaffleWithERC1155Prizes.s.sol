// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Scripting tool
import {Script} from "../../lib/forge-std/src/Script.sol";

// Core contracts
import {Raffle} from "../../contracts/Raffle.sol";
import {IRaffle} from "../../contracts/interfaces/IRaffle.sol";

import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";

interface ITestERC1155 {
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external;

    function setApprovalForAll(address operator, bool approved) external;
}

contract CreateRaffleWithERC1155Prizes is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 chainId = block.chainid;
        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");

        if (chainId != 5 && chainId != 11155111) {
            revert ChainIdInvalid(chainId);
        }

        vm.startBroadcast(deployerPrivateKey);

        Raffle raffle = Raffle(0xb0C8a1a0569F7302d36e380755f1835C3e59aCB9);

        address[] memory currencies = new address[](1);
        currencies[0] = 0x20A5A36ded0E4101C3688CBC405bBAAE58fE9eeC;
        raffle.updateCurrenciesStatus(currencies, true);

        IRaffle.PricingOption[5] memory pricingOptions;
        pricingOptions[0] = IRaffle.PricingOption({entriesCount: 1, price: 0.0000025 ether});
        pricingOptions[1] = IRaffle.PricingOption({entriesCount: 10, price: 0.000022 ether});
        pricingOptions[2] = IRaffle.PricingOption({entriesCount: 25, price: 0.00005 ether});
        pricingOptions[3] = IRaffle.PricingOption({entriesCount: 50, price: 0.000075 ether});
        pricingOptions[4] = IRaffle.PricingOption({entriesCount: 100, price: 0.000095 ether});

        ITestERC1155 nft = ITestERC1155(0x58c3c2547084CC1C94130D6fd750A3877c7Ca5D2);
        nft.setApprovalForAll(address(raffle), true);

        IERC20 looks = IERC20(0x20A5A36ded0E4101C3688CBC405bBAAE58fE9eeC);

        looks.approve(address(raffle), 3_000e18);

        IRaffle.Prize[] memory prizes = new IRaffle.Prize[](7);
        for (uint256 i; i < 6; ) {
            nft.mint(0xF332533bF5d0aC462DC8511067A8122b4DcE2B57, i, 4);

            if (i != 0) {
                prizes[i].prizeTier = 1;
            }

            prizes[i].prizeType = IRaffle.TokenType.ERC1155;
            prizes[i].prizeAddress = address(nft);
            prizes[i].prizeId = i;
            prizes[i].prizeAmount = 2;
            prizes[i].winnersCount = 2;

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
                minimumEntries: 20,
                maximumEntriesPerParticipant: 20,
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
