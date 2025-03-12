// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

// Core contracts
import {IRaffleV2} from "../../contracts/interfaces/IRaffleV2.sol";

contract SimulationBase {
    address public constant MAINNET_ERC_721 = 0xee726929543222D755145B1063c38eFba87bE601;
    address public constant MAINNET_ERC_721_B = 0xa589d2bb4FE9B371291C7Ef177A6076Ed1Fb2de8;
    address public constant MAINNET_ERC_20 = 0xf4d2888d29D722226FafA5d9B24F9164c092421E;
    address public constant MAINNET_RAFFLE = 0x0000000000aDEaD599C11A0C9a7475B67852c1D0;

    address public constant SEPOLIA_ERC_721 = 0x61AAEcdbe9C2502a72fec63F2Ff510bE1b95DD97;
    address public constant SEPOLIA_ERC_20 = 0xa68c2CaA3D45fa6EBB95aA706c70f49D3356824E;
    address public constant SEPOLIA_ERC_1155 = 0xE29BcBb8145B8A281BaBDd956e1595b1b76ddAfb;
    address public constant SEPOLIA_RAFFLE = 0xdA1DB8d3577CB26876Db10f178B18737D4502A94;

    address public constant GOERLI_ERC_721 = 0x77566D540d1E207dFf8DA205ed78750F9a1e7c55;
    address public constant GOERLI_ERC_721_B = 0x6019EaF9d6004582248b8F6C5b668675Ce6D22fe;
    address public constant GOERLI_ERC_20 = 0x20A5A36ded0E4101C3688CBC405bBAAE58fE9eeC;
    address public constant GOERLI_ERC_1155 = 0x58c3c2547084CC1C94130D6fd750A3877c7Ca5D2;
    address public constant GOERLI_RAFFLE = 0xda28aC345040C9abC0E19AfD6025c4f5A45C4b30;
    address public constant GOERLI_TRANSFER_MANAGER = 0xb737687983D6CcB4003A727318B5454864Ecba9d;

    address public constant RAFFLE_OWNER = 0xF332533bF5d0aC462DC8511067A8122b4DcE2B57;

    function getRaffle(uint256 chainId) internal pure returns (IRaffleV2 raffle) {
        if (chainId == 1) {
            raffle = IRaffleV2(MAINNET_RAFFLE);
        } else if (chainId == 5) {
            raffle = IRaffleV2(GOERLI_RAFFLE);
        } else if (chainId == 11155111) {
            raffle = IRaffleV2(SEPOLIA_RAFFLE);
        } else {
            revert("Invalid chainId");
        }
    }

    function getERC20(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return MAINNET_ERC_20;
        } else if (chainId == 5) {
            return GOERLI_ERC_20;
        } else if (chainId == 11155111) {
            return SEPOLIA_ERC_20;
        } else {
            revert("Invalid chainId");
        }
    }

    function getERC721(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return MAINNET_ERC_721;
        } else if (chainId == 5) {
            return GOERLI_ERC_721;
        } else if (chainId == 11155111) {
            return SEPOLIA_ERC_721;
        } else {
            revert("Invalid chainId");
        }
    }

    function getERC721B(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) {
            return MAINNET_ERC_721_B;
        } else if (chainId == 5) {
            return GOERLI_ERC_721_B;
        } else {
            revert("Invalid chainId");
        }
    }

    function getERC1155(uint256 chainId) internal pure returns (address) {
        return chainId == 5 ? GOERLI_ERC_1155 : SEPOLIA_ERC_1155;
    }

    function getTransferManager(uint256 chainId) internal pure returns (address) {
        return chainId == 5 ? GOERLI_TRANSFER_MANAGER : address(0);
    }
}
