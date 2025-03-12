// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library NumericArrayLib {
    // This function sort array in memory using bubble sort algorithm,
    // which performs even better than quick sort for small arrays

    uint256 internal constant BYTES_ARR_LEN_VAR_BS = 32;
    uint256 internal constant UINT256_VALUE_BS = 32;

    error CanNotPickMedianOfEmptyArray();

    // This function modifies the array
    function pickMedian(uint256[] memory arr) internal pure returns (uint256) {
        if (arr.length == 0) {
            revert CanNotPickMedianOfEmptyArray();
        }
        sort(arr);
        uint256 middleIndex = arr.length / 2;
        if (arr.length % 2 == 0) {
            uint256 sum = arr[middleIndex - 1] + arr[middleIndex];
            return sum / 2;
        } else {
            return arr[middleIndex];
        }
    }

    function sort(uint256[] memory arr) internal pure {
        assembly {
            let arrLength := mload(arr)
            let valuesPtr := add(arr, BYTES_ARR_LEN_VAR_BS)
            let endPtr := add(valuesPtr, mul(arrLength, UINT256_VALUE_BS))
            for {
                let arrIPtr := valuesPtr
            } lt(arrIPtr, endPtr) {
                arrIPtr := add(arrIPtr, UINT256_VALUE_BS) // arrIPtr += 32
            } {
                for {
                    let arrJPtr := valuesPtr
                } lt(arrJPtr, arrIPtr) {
                    arrJPtr := add(arrJPtr, UINT256_VALUE_BS) // arrJPtr += 32
                } {
                    let arrI := mload(arrIPtr)
                    let arrJ := mload(arrJPtr)
                    if lt(arrI, arrJ) {
                        mstore(arrIPtr, arrJ)
                        mstore(arrJPtr, arrI)
                    }
                }
            }
        }
    }
}

/**
 * @title Default implementations of virtual redstone consumer base functions
 * @author The Redstone Oracles team
 */
library RedstoneDefaultsLib {
    uint256 internal constant DEFAULT_MAX_DATA_TIMESTAMP_DELAY_SECONDS = 3 minutes;
    uint256 internal constant DEFAULT_MAX_DATA_TIMESTAMP_AHEAD_SECONDS = 1 minutes;

    error TimestampFromTooLongFuture(uint256 receivedTimestampSeconds, uint256 blockTimestamp);
    error TimestampIsTooOld(uint256 receivedTimestampSeconds, uint256 blockTimestamp);

    function validateTimestamp(uint256 receivedTimestampMilliseconds) internal view {
        // Getting data timestamp from future seems quite unlikely
        // But we've already spent too much time with different cases
        // Where block.timestamp was less than dataPackage.timestamp.
        // Some blockchains may case this problem as well.
        // That's why we add MAX_BLOCK_TIMESTAMP_DELAY
        // and allow data "from future" but with a small delay
        uint256 receivedTimestampSeconds = receivedTimestampMilliseconds / 1000;

        if (block.timestamp < receivedTimestampSeconds) {
            if ((receivedTimestampSeconds - block.timestamp) > DEFAULT_MAX_DATA_TIMESTAMP_AHEAD_SECONDS) {
                revert TimestampFromTooLongFuture(receivedTimestampSeconds, block.timestamp);
            }
        } else if ((block.timestamp - receivedTimestampSeconds) > DEFAULT_MAX_DATA_TIMESTAMP_DELAY_SECONDS) {
            revert TimestampIsTooOld(receivedTimestampSeconds, block.timestamp);
        }
    }

    function aggregateValues(uint256[] memory values) internal pure returns (uint256) {
        return NumericArrayLib.pickMedian(values);
    }
}

library BitmapLib {
    function setBitInBitmap(uint256 bitmap, uint256 bitIndex) internal pure returns (uint256) {
        return bitmap | (1 << bitIndex);
    }

    function getBitFromBitmap(uint256 bitmap, uint256 bitIndex) internal pure returns (bool) {
        uint256 bitAtIndex = bitmap & (1 << bitIndex);
        return bitAtIndex > 0;
    }
}

library SignatureLib {
    uint256 internal constant ECDSA_SIG_R_BS = 32;
    uint256 internal constant ECDSA_SIG_S_BS = 32;

    function recoverSignerAddress(bytes32 signedHash, uint256 signatureCalldataNegativeOffset) internal pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            let signatureCalldataStartPos := sub(calldatasize(), signatureCalldataNegativeOffset)
            r := calldataload(signatureCalldataStartPos)
            signatureCalldataStartPos := add(signatureCalldataStartPos, ECDSA_SIG_R_BS)
            s := calldataload(signatureCalldataStartPos)
            signatureCalldataStartPos := add(signatureCalldataStartPos, ECDSA_SIG_S_BS)
            v := byte(0, calldataload(signatureCalldataStartPos)) // last byte of the signature memory array
        }
        return ecrecover(signedHash, v, r, s);
    }
}

/**
 * @title The base contract with helpful constants
 * @author The Redstone Oracles team
 * @dev It mainly contains redstone-related values, which improve readability
 * of other contracts (e.g. CalldataExtractor and RedstoneConsumerBase)
 */
library RedstoneError {
    // Error messages
    error ProxyCalldataFailedWithoutErrMsg2();
    error ProxyCalldataFailedWithoutErrMsg();
    error CalldataOverOrUnderFlow();
    error ProxyCalldataFailedWithCustomError(bytes result);
    error IncorrectUnsignedMetadataSize();
    error ProxyCalldataFailedWithStringMessage(string);
    error InsufficientNumberOfUniqueSigners(uint256 receivedSignersCount, uint256 requiredSignersCount);
    error EachSignerMustProvideTheSameValue();
    error EmptyCalldataPointersArr();
    error InvalidCalldataPointer();
    error CalldataMustHaveValidPayload();
    error SignerNotAuthorised(address receivedSigner);
}
