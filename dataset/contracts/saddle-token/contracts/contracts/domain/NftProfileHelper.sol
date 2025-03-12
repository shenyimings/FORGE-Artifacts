// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "../interface/INftProfileHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NftProfileHelper is INftProfileHelper, Ownable {
    mapping(bytes1 => bool) _allowedChar;

    constructor() {
        _allowedChar["a"] = true;
        _allowedChar["b"] = true;
        _allowedChar["c"] = true;
        _allowedChar["d"] = true;
        _allowedChar["e"] = true;
        _allowedChar["f"] = true;
        _allowedChar["g"] = true;
        _allowedChar["h"] = true;
        _allowedChar["i"] = true;
        _allowedChar["j"] = true;
        _allowedChar["k"] = true;
        _allowedChar["l"] = true;
        _allowedChar["m"] = true;
        _allowedChar["n"] = true;
        _allowedChar["o"] = true;
        _allowedChar["p"] = true;
        _allowedChar["q"] = true;
        _allowedChar["r"] = true;
        _allowedChar["s"] = true;
        _allowedChar["t"] = true;
        _allowedChar["u"] = true;
        _allowedChar["v"] = true;
        _allowedChar["w"] = true;
        _allowedChar["x"] = true;
        _allowedChar["y"] = true;
        _allowedChar["z"] = true;
        _allowedChar["0"] = true;
        _allowedChar["1"] = true;
        _allowedChar["2"] = true;
        _allowedChar["3"] = true;
        _allowedChar["4"] = true;
        _allowedChar["5"] = true;
        _allowedChar["6"] = true;
        _allowedChar["7"] = true;
        _allowedChar["8"] = true;
        _allowedChar["9"] = true;
        _allowedChar["_"] = true;
    }

    function bytesStringLength(string memory _string) private pure returns (uint256) {
        return bytes(_string).length;
    }

    function correctLength(string memory _string) private pure returns (bool) {
        return bytesStringLength(_string) > 0 && bytesStringLength(_string) <= 60;
    }

    function changeAllowedChar(string memory char, bool flag) external onlyOwner {
        require(bytesStringLength(char) == 1, "invalid length");
        _allowedChar[bytes1(bytes(char))] = flag;
    }

    /**
     @notice checks for a valid URI with length and allowed characters
     @param _name string for a given URI
     @return true if valid
    */
    function _validURI(string memory _name) external view override returns (bool) {
        require(correctLength(_name), "invalid length");
        bytes memory byteString = bytes(_name);
        for (uint256 i = 0; i < byteString.length; i++) {
            if (!_allowedChar[byteString[i]]) return false;
        }
        return true;
    }
}
