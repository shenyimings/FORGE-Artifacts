pragma solidity 0.4.25;

import "./SafeMath256.sol";
import "./SafeConvert.sol";
import "./Upgradable.sol";

contract Random is Upgradable {
    using SafeMath256 for uint256;
    using SafeConvert for uint256;

    function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
        return b > a ? 0 : a.sub(b);
    }

    modifier validBlock(uint256 _blockNumber) {
        require(
            _blockNumber < block.number &&
            _blockNumber >= _safeSub(block.number, 256),
            "not valid block number"
        );
        _;
    }

    function getRandom(
        uint256 _upper,
        uint256 _blockNumber
    ) internal view validBlock(_blockNumber) returns (uint256) {
        bytes32 _hash = keccak256(abi.encodePacked(blockhash(_blockNumber), now)); // solium-disable-line security/no-block-members
        return uint256(_hash) % _upper;
    }

    function random(uint256 _upper) external view returns (uint256) {
        return getRandom(_upper, block.number.sub(1));
    }

    function randomOfBlock(
        uint256 _upper,
        uint256 _blockNumber
    ) external view returns (uint256) {
        return getRandom(_upper, _blockNumber);
    }
}
