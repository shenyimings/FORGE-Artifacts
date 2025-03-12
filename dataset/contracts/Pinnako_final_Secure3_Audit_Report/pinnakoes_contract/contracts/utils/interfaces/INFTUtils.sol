// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTUtils {
    function genReferralCode(uint256 _accountId) external pure returns (string memory);

    function attributeForTypeAndValue(
        string memory traitType,
        string memory value
    ) external pure returns (string memory);

    function toChar(uint8 d) external pure returns (bytes1);

    function toHexString(uint a) external pure returns (string memory);

    function base64(bytes memory data) external pure returns (string memory);
}


