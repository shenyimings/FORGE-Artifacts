// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IERC721.sol";
import "./ERC712Domain.sol";

contract Auction is Initializable, OwnableUpgradeable, ERC712Domain {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public beneficiary;
    address public operator;
    uint256 public items;
    IERC20Upgradeable public weth;
    IERC721 public nft;

    mapping(address => uint256) public used;

    modifier onlyOperator() {
        require(_msgSender() == operator, "Must be the operator");
        _;
    }

    function initialize(
        IERC721 nft_,
        uint256 items_,
        IERC20Upgradeable weth_,
        address beneficiary_,
        address operator_
    ) external initializer {
        __Ownable_init();
        _erc712DomainInit('$CAR Auction', '1');

        nft = nft_;
        items = items_;
        weth = weth_;
        beneficiary = beneficiary_;
        operator = operator_;
    }

    function setBeneficiary(address beneficiary_) external onlyOwner {
        beneficiary = beneficiary_;
    }

    function setOperator(address operator_) external onlyOwner {
        operator = operator_;
    }

    function setWeth(IERC20Upgradeable weth_) external onlyOwner {
        weth = weth_;
    }

    function setNFT(IERC721 nft_) external onlyOwner {
        nft = nft_;
    }

    function selectWinners(
        address[] calldata bidders,
        uint256[] calldata bids,
        bytes32[] calldata formattedAmountHashes,
        bytes32[] memory sigsR,
        bytes32[] memory sigsS,
        uint8[] memory sigsV,
        uint256 startID
    ) external onlyOperator returns (uint256) {
        require(bidders.length <= items, "Too much winners");
        require(bidders.length == bids.length, "Incorrect number of bids");
        require(bidders.length == formattedAmountHashes.length, "Incorrect number of formatted amount hashes");
        require(
            bidders.length == sigsV.length &&
                sigsV.length == sigsR.length &&
                sigsV.length == sigsS.length,
            "Incorrect number of signatures"
        );
        uint256 minted = 0;
        for (uint256 i = 0; i < bidders.length; i++) {
            require(used[bidders[i]] == 0, "Already used");
            used[bidders[i]] = bids[i];
            if (
                !erc712Verify(
                    bidders[i], hashBid(bids[i], formattedAmountHashes[i]), sigsV[i], sigsR[i], sigsS[i]
                )
            ) {
                continue;
            }
            if (
                weth.allowance(bidders[i], address(this)) < bids[i] ||
                weth.balanceOf(bidders[i]) < bids[i]
            ) {
                continue;
            }
            weth.safeTransferFrom(bidders[i], beneficiary, bids[i]);
            nft.mint(bidders[i], startID + minted);
            minted++;
        }
        items -= minted;
        return minted;
    }

    bytes32 constant BID_CONTENTS_HASH = keccak256(bytes(
        'Please sign to confirm your bid. The amounts are shown in WEI and ETH.'
    ));

    bytes32 constant BID_TYPEHASH = keccak256(bytes(
        'Bid(uint256 amount,string contents,address tokenContract,string formattedAmount)'
    ));

    function hashBid(uint256 amount, bytes32 formattedAmountHash) public view returns (bytes32) {
        return keccak256(abi.encode(
            BID_TYPEHASH,
            amount,
            BID_CONTENTS_HASH,
            address(weth),
            formattedAmountHash
        ));
    }
}
