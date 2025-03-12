// SPDX-License-Identifier: GPL-3.0
// solhint-disable not-rely-on-time
// solhint-disable no-empty-blocks
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {Constants} from "./libs/Constants.sol";
import {FeeTracker} from "./base/FeeTracker.sol";
import {MoeMigratable} from "./base/Migratable.sol";

/**
 * Class for the XPOW proof-of-work tokens: It verifies, that the nonce and the
 * block-hash result in a positive amount. After a successful verification, the
 * corresponding amount is minted for the beneficiary (plus the MoE treasury).
 */
contract XPower is ERC20, ERC20Burnable, FeeTracker, MoeMigratable, Ownable {
    /** set of nonce-hashes already minted for */
    mapping(bytes32 => bool) private _hashes;
    /** map from block-hashes to timestamps */
    mapping(bytes32 => uint256) private _timestamps;
    /** map from intervals to block-hashes */
    mapping(uint256 => bytes32) private _blockHashes;

    /** @param moeBase addresses of old contracts */
    /** @param deadlineIn seconds to end-of-migration */
    constructor(
        address[] memory moeBase,
        uint256 deadlineIn
    )
        // ERC20 constructor: name, symbol
        ERC20("XPower", "XPOW")
        // MoeMigratable: old contract, rel. deadline [seconds]
        MoeMigratable(moeBase, deadlineIn)
    {}

    /** @return number of decimals of representation */
    function decimals() public view virtual override returns (uint8) {
        return Constants.DECIMALS;
    }

    /** emitted on caching most recent block-hash */
    event Init(bytes32 blockHash, uint256 timestamp);

    /** cache most recent block-hash */
    function init() external {
        uint256 interval = currentInterval();
        assert(interval > 0);
        if (uint256(_blockHashes[interval]) == 0) {
            bytes32 blockHash = blockhash(block.number - 1);
            assert(blockHash > 0);
            uint256 timestamp = block.timestamp;
            assert(timestamp > 0);
            _blockHashes[interval] = blockHash;
            _timestamps[blockHash] = timestamp;
            emit Init(blockHash, timestamp);
        } else {
            bytes32 blockHash = _blockHashes[interval];
            uint256 timestamp = _timestamps[blockHash];
            emit Init(blockHash, timestamp);
        }
    }

    /** mint tokens for to-beneficiary, block-hash & data (incl. nonce) */
    function mint(
        address to,
        bytes32 blockHash,
        bytes calldata data
    ) external tracked {
        // check block-hash to be in current interval
        require(_recent(blockHash), "expired block-hash");
        // calculate nonce-hash & pair-index for to, block-hash & data
        (bytes32 nonceHash, bytes32 pairIndex) = _hashOf(to, blockHash, data);
        require(_unique(pairIndex), "duplicate nonce-hash");
        // calculate number of zeros of nonce-hash
        uint256 zeros = _zerosOf(nonceHash);
        require(zeros > 0, "empty nonce-hash");
        // calculate amount of tokens of zeros
        uint256 amount = _amountOf(zeros);
        // ensure unique (nonce-hash, block-hash)
        _hashes[pairIndex] = true;
        // mint for contract owner
        _mint(owner(), amount >> 3);
        // mint for beneficiary
        _mint(to, amount);
    }

    /** @return block-hash */
    function blockHashOf(uint256 interval) external view returns (bytes32) {
        return _blockHashes[interval];
    }

    /** @return current interval's timestamp */
    function currentInterval() public view returns (uint256) {
        return block.timestamp / (1 hours);
    }

    /** check whether block-hash has recently been cached */
    function _recent(bytes32 blockHash) private view returns (bool) {
        return _timestamps[blockHash] > currentInterval();
    }

    /** @return hash of contract, to-beneficiary, block-hash & data (incl. nonce) */
    function _hashOf(
        address to,
        bytes32 blockHash,
        bytes calldata data
    ) internal view returns (bytes32, bytes32) {
        bytes32 nonceHash = keccak256(
            bytes.concat(
                bytes20(uint160(address(this)) ^ uint160(to)),
                blockHash,
                data
            )
        );
        return (nonceHash, nonceHash ^ blockHash);
    }

    /** check whether (nonce-hash, block-hash) pair is unique */
    function _unique(bytes32 pairIndex) private view returns (bool) {
        return !_hashes[pairIndex];
    }

    /** @return number of leading-zeros */
    function _zerosOf(bytes32 nonceHash) internal pure returns (uint8) {
        if (nonceHash > 0) {
            return uint8(63 - (Math.log2(uint256(nonceHash)) >> 2));
        }
        return 64;
    }

    /** @return amount (for level) */
    function _amountOf(uint256 level) internal view returns (uint256) {
        return (2 ** level - 1) * 10 ** decimals();
    }

    /** @return true if this contract implements the interface defined by interface-id */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(MoeMigratable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /** @return fee-estimate plus averages over gas and gas-price */
    function fees() external view returns (uint256[] memory) {
        return _fees(FEE_ADD, FEE_MUL, FEE_DIV);
    }

    /** fee-tracker estimate: 21_000+700+1360+1088+68*8 */
    uint256 private constant FEE_ADD = 24_692_000_000_000;
    uint256 private constant FEE_MUL = 1_6168707436776024;
    uint256 private constant FEE_DIV = 1_0000000000000000;
}
