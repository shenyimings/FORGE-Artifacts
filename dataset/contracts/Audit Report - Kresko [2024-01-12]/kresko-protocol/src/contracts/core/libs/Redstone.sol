// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
import {BitmapLib, SignatureLib, RedstoneError, RedstoneDefaultsLib} from "./RedstoneInternals.sol";

// solhint-disable no-empty-blocks
// solhint-disable avoid-low-level-calls

// === Abbreviations ===
// BS - Bytes size
// PTR - Pointer (memory location)
// SIG - Signature

library Redstone {
    // Solidity and YUL constants
    uint256 internal constant STANDARD_SLOT_BS = 32;
    uint256 internal constant FREE_MEMORY_PTR = 0x40;
    uint256 internal constant BYTES_ARR_LEN_VAR_BS = 32;
    uint256 internal constant FUNCTION_SIGNATURE_BS = 4;
    uint256 internal constant REVERT_MSG_OFFSET = 68; // Revert message structure described here: https://ethereum.stackexchange.com/a/66173/106364
    uint256 internal constant STRING_ERR_MESSAGE_MASK = 0x08c379a000000000000000000000000000000000000000000000000000000000;

    // RedStone protocol consts
    uint256 internal constant SIG_BS = 65;
    uint256 internal constant TIMESTAMP_BS = 6;
    uint256 internal constant DATA_PACKAGES_COUNT_BS = 2;
    uint256 internal constant DATA_POINTS_COUNT_BS = 3;
    uint256 internal constant DATA_POINT_VALUE_BYTE_SIZE_BS = 4;
    uint256 internal constant DATA_POINT_SYMBOL_BS = 32;
    uint256 internal constant DEFAULT_DATA_POINT_VALUE_BS = 32;
    uint256 internal constant UNSIGNED_METADATA_BYTE_SIZE_BS = 3;
    uint256 internal constant REDSTONE_MARKER_BS = 9; // byte size of 0x000002ed57011e0000
    uint256 internal constant REDSTONE_MARKER_MASK = 0x0000000000000000000000000000000000000000000000000002ed57011e0000;

    // Derived values (based on consts)
    uint256 internal constant TIMESTAMP_NEGATIVE_OFFSET_IN_DATA_PACKAGE_WITH_STANDARD_SLOT_BS = 104; // SIG_BS + DATA_POINTS_COUNT_BS + DATA_POINT_VALUE_BYTE_SIZE_BS + STANDARD_SLOT_BS
    uint256 internal constant DATA_PACKAGE_WITHOUT_DATA_POINTS_BS = 78; // DATA_POINT_VALUE_BYTE_SIZE_BS + TIMESTAMP_BS + DATA_POINTS_COUNT_BS + SIG_BS
    uint256 internal constant DATA_PACKAGE_WITHOUT_DATA_POINTS_AND_SIG_BS = 13; // DATA_POINT_VALUE_BYTE_SIZE_BS + TIMESTAMP_BS + DATA_POINTS_COUNT_BS
    uint256 internal constant REDSTONE_MARKER_BS_PLUS_STANDARD_SLOT_BS = 41; // REDSTONE_MARKER_BS + STANDARD_SLOT_BS

    // using SafeMath for uint256;
    // inside unchecked these functions are still checked
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    using {sub, add} for uint256;

    /**
     * @dev This function can be used in a consumer contract to securely extract an
     * oracle value for a given data feed id. Security is achieved by
     * signatures verification, timestamp validation, and aggregating values
     * from different authorised signers into a single numeric value. If any of the
     * required conditions do not match, the function will revert.
     * Note! This function expects that tx calldata contains redstone payload in the end
     * Learn more about redstone payload here: https://github.com/redstone-finance/redstone-oracles-monorepo/tree/main/packages/evm-connector#readme
     * @param dataFeedId bytes32 value that uniquely identifies the data feed
     * @return Extracted and verified numeric oracle value for the given data feed id
     */
    function getPrice(bytes32 dataFeedId) internal view returns (uint256) {
        bytes32[] memory dataFeedIds = new bytes32[](1);
        dataFeedIds[0] = dataFeedId;
        return _securelyExtractOracleValuesFromTxMsg(dataFeedIds)[0];
    }

    function getAuthorisedSignerIndex(address signerAddress) internal pure returns (uint8) {
        if (signerAddress == 0x926E370fD53c23f8B71ad2B3217b227E41A92b12) return 0;
        if (signerAddress == 0x0C39486f770B26F5527BBBf942726537986Cd7eb) return 1;
        // For testing hardhat signer 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 is authorised
        // will be removed in production deployment
        if (signerAddress == 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) return 2;

        revert RedstoneError.SignerNotAuthorised(signerAddress);
    }

    /**
     * @dev This function can be used in a consumer contract to securely extract several
     * numeric oracle values for a given array of data feed ids. Security is achieved by
     * signatures verification, timestamp validation, and aggregating values
     * from different authorised signers into a single numeric value. If any of the
     * required conditions do not match, the function will revert.
     * Note! This function expects that tx calldata contains redstone payload in the end
     * Learn more about redstone payload here: https://github.com/redstone-finance/redstone-oracles-monorepo/tree/main/packages/evm-connector#readme
     * @param dataFeedIds An array of unique data feed identifiers
     * @return An array of the extracted and verified oracle values in the same order
     * as they are requested in the dataFeedIds array
     */
    function getPrices(bytes32[] memory dataFeedIds) internal view returns (uint256[] memory) {
        return _securelyExtractOracleValuesFromTxMsg(dataFeedIds);
    }

    /**
     * @dev This function may be overridden by the child consumer contract.
     * It should validate the timestamp against the current time (block.timestamp)
     * It should revert with a helpful message if the timestamp is not valid
     * @param receivedTimestampMilliseconds Timestamp extracted from calldata
     */
    function validateTimestamp(uint256 receivedTimestampMilliseconds) internal view {
        // For testing this function is disabled
        // Uncomment this line to enable timestamp validation in prod
        // RedstoneDefaultsLib.validateTimestamp(receivedTimestampMilliseconds);
    }

    /**
     * @dev This function should be overridden by the child consumer contract.
     * @return The minimum required value of unique authorised signers
     */
    function getUniqueSignersThreshold() internal pure returns (uint8) {
        return 1;
    }

    /**
     * @dev This function may be overridden by the child consumer contract.
     * It should aggregate values from different signers to a single uint value.
     * By default, it calculates the median value
     * @param values An array of uint256 values from different signers
     * @return Result of the aggregation in the form of a single number
     */
    function aggregateValues(uint256[] memory values) internal pure returns (uint256) {
        return RedstoneDefaultsLib.aggregateValues(values);
    }

    /**
     * @dev This is an internal helpful function for secure extraction oracle values
     * from the tx calldata. Security is achieved by signatures verification, timestamp
     * validation, and aggregating values from different authorised signers into a
     * single numeric value. If any of the required conditions (e.g. too old timestamp or
     * insufficient number of authorised signers) do not match, the function will revert.
     *
     * Note! You should not call this function in a consumer contract. You can use
     * `getOracleNumericValuesFromTxMsg` or `getOracleNumericValueFromTxMsg` instead.
     *
     * @param dataFeedIds An array of unique data feed identifiers
     * @return An array of the extracted and verified oracle values in the same order
     * as they are requested in dataFeedIds array
     */
    function _securelyExtractOracleValuesFromTxMsg(bytes32[] memory dataFeedIds) private view returns (uint256[] memory) {
        // Initializing helpful variables and allocating memory
        uint256[] memory uniqueSignerCountForDataFeedIds = new uint256[](dataFeedIds.length);
        uint256[] memory signersBitmapForDataFeedIds = new uint256[](dataFeedIds.length);
        uint256[][] memory valuesForDataFeeds = new uint256[][](dataFeedIds.length);
        for (uint256 i; i < dataFeedIds.length; ) {
            // The line below is commented because newly allocated arrays are filled with zeros
            // But we left it for better readability
            // signersBitmapForDataFeedIds[i] = 0; // <- setting to an empty bitmap
            valuesForDataFeeds[i] = new uint256[](getUniqueSignersThreshold());

            unchecked {
                i++;
            }
        }

        // Extracting the number of data packages from calldata
        uint256 calldataNegativeOffset = _extractByteSizeOfUnsignedMetadata();
        uint256 dataPackagesCount = _extractDataPackagesCountFromCalldata(calldataNegativeOffset);
        unchecked {
            calldataNegativeOffset += DATA_PACKAGES_COUNT_BS;
        }

        // Saving current free memory pointer
        uint256 freeMemPtr;
        assembly {
            freeMemPtr := mload(FREE_MEMORY_PTR)
        }

        // Data packages extraction in a loop
        for (uint256 dataPackageIndex; dataPackageIndex < dataPackagesCount; ) {
            // Extract data package details and update calldata offset
            uint256 dataPackageByteSize = _extractDataPackage(
                dataFeedIds,
                uniqueSignerCountForDataFeedIds,
                signersBitmapForDataFeedIds,
                valuesForDataFeeds,
                calldataNegativeOffset
            );
            unchecked {
                calldataNegativeOffset += dataPackageByteSize;
            }

            // Shifting memory pointer back to the "safe" value
            assembly {
                mstore(FREE_MEMORY_PTR, freeMemPtr)
            }

            unchecked {
                dataPackageIndex++;
            }
        }

        // Validating numbers of unique signers and calculating aggregated values for each dataFeedId
        return _getAggregatedValues(valuesForDataFeeds, uniqueSignerCountForDataFeedIds);
    }

    /**
     * @dev This is a private helpful function, which extracts data for a data package based
     * on the given negative calldata offset, verifies them, and in the case of successful
     * verification updates the corresponding data package values in memory
     *
     * @param dataFeedIds an array of unique data feed identifiers
     * @param uniqueSignerCountForDataFeedIds an array with the numbers of unique signers
     * for each data feed
     * @param signersBitmapForDataFeedIds an array of signer bitmaps for data feeds
     * @param valuesForDataFeeds 2-dimensional array, valuesForDataFeeds[i][j] contains
     * j-th value for the i-th data feed
     * @param calldataNegativeOffset negative calldata offset for the given data package
     *
     * @return An array of the aggregated values
     */
    function _extractDataPackage(
        bytes32[] memory dataFeedIds,
        uint256[] memory uniqueSignerCountForDataFeedIds,
        uint256[] memory signersBitmapForDataFeedIds,
        uint256[][] memory valuesForDataFeeds,
        uint256 calldataNegativeOffset
    ) private view returns (uint256) {
        uint256 signerIndex;

        (uint256 dataPointsCount, uint256 eachDataPointValueByteSize) = _extractDataPointsDetailsForDataPackage(
            calldataNegativeOffset
        );

        // We use scopes to resolve problem with too deep stack
        {
            uint48 extractedTimestamp;
            address signerAddress;
            bytes32 signedHash;
            bytes memory signedMessage;
            uint256 signedMessageBytesCount = dataPointsCount *
                (eachDataPointValueByteSize + DATA_POINT_SYMBOL_BS) +
                DATA_PACKAGE_WITHOUT_DATA_POINTS_AND_SIG_BS; //DATA_POINT_VALUE_BYTE_SIZE_BS + TIMESTAMP_BS + DATA_POINTS_COUNT_BS

            unchecked {
                uint256 timestampCalldataOffset = msg.data.length.sub(
                    calldataNegativeOffset + TIMESTAMP_NEGATIVE_OFFSET_IN_DATA_PACKAGE_WITH_STANDARD_SLOT_BS
                );

                uint256 signedMessageCalldataOffset = msg.data.length.sub(
                    calldataNegativeOffset + SIG_BS + signedMessageBytesCount
                );

                assembly {
                    // Extracting the signed message
                    signedMessage := extractBytesFromCalldata(signedMessageCalldataOffset, signedMessageBytesCount)

                    // Hashing the signed message
                    signedHash := keccak256(add(signedMessage, BYTES_ARR_LEN_VAR_BS), signedMessageBytesCount)

                    // Extracting timestamp
                    extractedTimestamp := calldataload(timestampCalldataOffset)

                    function initByteArray(bytesCount) -> ptr {
                        ptr := mload(FREE_MEMORY_PTR)
                        mstore(ptr, bytesCount)
                        ptr := add(ptr, BYTES_ARR_LEN_VAR_BS)
                        mstore(FREE_MEMORY_PTR, add(ptr, bytesCount))
                    }

                    function extractBytesFromCalldata(offset, bytesCount) -> extractedBytes {
                        let extractedBytesStartPtr := initByteArray(bytesCount)
                        calldatacopy(extractedBytesStartPtr, offset, bytesCount)
                        extractedBytes := sub(extractedBytesStartPtr, BYTES_ARR_LEN_VAR_BS)
                    }
                }
            }
            // Validating timestamp
            validateTimestamp(extractedTimestamp);

            // Verifying the off-chain signature against on-chain hashed data
            signerAddress = SignatureLib.recoverSignerAddress(signedHash, calldataNegativeOffset + SIG_BS);
            signerIndex = getAuthorisedSignerIndex(signerAddress);
        }

        // Updating helpful arrays
        {
            bytes32 dataPointDataFeedId;
            uint256 dataPointValue;
            for (uint256 dataPointIndex; dataPointIndex < dataPointsCount; ) {
                // Extracting data feed id and value for the current data point
                (dataPointDataFeedId, dataPointValue) = _extractDataPointValueAndDataFeedId(
                    calldataNegativeOffset,
                    eachDataPointValueByteSize,
                    dataPointIndex
                );

                for (uint256 dataFeedIdIndex; dataFeedIdIndex < dataFeedIds.length; ) {
                    if (dataPointDataFeedId == dataFeedIds[dataFeedIdIndex]) {
                        uint256 bitmapSignersForDataFeedId = signersBitmapForDataFeedIds[dataFeedIdIndex];

                        if (
                            !BitmapLib.getBitFromBitmap(
                                bitmapSignersForDataFeedId,
                                signerIndex
                            ) /* current signer was not counted for current dataFeedId */ &&
                            uniqueSignerCountForDataFeedIds[dataFeedIdIndex] < getUniqueSignersThreshold()
                        ) {
                            unchecked {
                                // Increase unique signer counter
                                uniqueSignerCountForDataFeedIds[dataFeedIdIndex]++;

                                // Add new value
                                valuesForDataFeeds[dataFeedIdIndex][
                                    uniqueSignerCountForDataFeedIds[dataFeedIdIndex] - 1
                                ] = dataPointValue;
                            }
                            // Update signers bitmap
                            signersBitmapForDataFeedIds[dataFeedIdIndex] = BitmapLib.setBitInBitmap(
                                bitmapSignersForDataFeedId,
                                signerIndex
                            );
                        }

                        // Breaking, as there couldn't be several indexes for the same feed ID
                        break;
                    }
                    unchecked {
                        dataFeedIdIndex++;
                    }
                }
                unchecked {
                    dataPointIndex++;
                }
            }
        }

        // Return total data package byte size
        unchecked {
            return DATA_PACKAGE_WITHOUT_DATA_POINTS_BS + (eachDataPointValueByteSize + DATA_POINT_SYMBOL_BS) * dataPointsCount;
        }
    }

    /**
     * @dev This is a private helpful function, which aggregates values from different
     * authorised signers for the given arrays of values for each data feed
     *
     * @param valuesForDataFeeds 2-dimensional array, valuesForDataFeeds[i][j] contains
     * j-th value for the i-th data feed
     * @param uniqueSignerCountForDataFeedIds an array with the numbers of unique signers
     * for each data feed
     *
     * @return An array of the aggregated values
     */
    function _getAggregatedValues(
        uint256[][] memory valuesForDataFeeds,
        uint256[] memory uniqueSignerCountForDataFeedIds
    ) private pure returns (uint256[] memory) {
        uint256[] memory aggregatedValues = new uint256[](valuesForDataFeeds.length);
        uint256 uniqueSignersThreshold = getUniqueSignersThreshold();

        for (uint256 dataFeedIndex; dataFeedIndex < valuesForDataFeeds.length; ) {
            if (uniqueSignerCountForDataFeedIds[dataFeedIndex] < uniqueSignersThreshold) {
                revert RedstoneError.InsufficientNumberOfUniqueSigners(
                    uniqueSignerCountForDataFeedIds[dataFeedIndex],
                    uniqueSignersThreshold
                );
            }
            uint256 aggregatedValueForDataFeedId = aggregateValues(valuesForDataFeeds[dataFeedIndex]);
            aggregatedValues[dataFeedIndex] = aggregatedValueForDataFeedId;
            unchecked {
                dataFeedIndex++;
            }
        }

        return aggregatedValues;
    }

    function _extractDataPointsDetailsForDataPackage(
        uint256 calldataNegativeOffsetForDataPackage
    ) private pure returns (uint256 dataPointsCount, uint256 eachDataPointValueByteSize) {
        // Using uint24, because data points count byte size number has 3 bytes
        uint24 dataPointsCount_;

        // Using uint32, because data point value byte size has 4 bytes
        uint32 eachDataPointValueByteSize_;

        // Extract data points count
        unchecked {
            uint256 negativeCalldataOffset = calldataNegativeOffsetForDataPackage + SIG_BS;
            uint256 calldataOffset = msg.data.length.sub(negativeCalldataOffset + STANDARD_SLOT_BS);
            assembly {
                dataPointsCount_ := calldataload(calldataOffset)
            }

            // Extract each data point value size
            calldataOffset = calldataOffset.sub(DATA_POINTS_COUNT_BS);
            assembly {
                eachDataPointValueByteSize_ := calldataload(calldataOffset)
            }

            // Prepare returned values
            dataPointsCount = dataPointsCount_;
            eachDataPointValueByteSize = eachDataPointValueByteSize_;
        }
    }

    function _extractByteSizeOfUnsignedMetadata() private pure returns (uint256) {
        // Checking if the calldata ends with the RedStone marker
        bool hasValidRedstoneMarker;
        assembly {
            let calldataLast32Bytes := calldataload(sub(calldatasize(), STANDARD_SLOT_BS))
            hasValidRedstoneMarker := eq(REDSTONE_MARKER_MASK, and(calldataLast32Bytes, REDSTONE_MARKER_MASK))
        }
        if (!hasValidRedstoneMarker) {
            revert RedstoneError.CalldataMustHaveValidPayload();
        }

        // Using uint24, because unsigned metadata byte size number has 3 bytes
        uint24 unsignedMetadataByteSize;
        if (REDSTONE_MARKER_BS_PLUS_STANDARD_SLOT_BS > msg.data.length) {
            revert RedstoneError.CalldataOverOrUnderFlow();
        }
        assembly {
            unsignedMetadataByteSize := calldataload(sub(calldatasize(), REDSTONE_MARKER_BS_PLUS_STANDARD_SLOT_BS))
        }
        unchecked {
            uint256 calldataNegativeOffset = unsignedMetadataByteSize + UNSIGNED_METADATA_BYTE_SIZE_BS + REDSTONE_MARKER_BS;
            if (calldataNegativeOffset + DATA_PACKAGES_COUNT_BS > msg.data.length) {
                revert RedstoneError.IncorrectUnsignedMetadataSize();
            }
            return calldataNegativeOffset;
        }
    }

    function _extractDataPackagesCountFromCalldata(
        uint256 calldataNegativeOffset
    ) private pure returns (uint16 dataPackagesCount) {
        unchecked {
            uint256 calldataNegativeOffsetWithStandardSlot = calldataNegativeOffset + STANDARD_SLOT_BS;
            if (calldataNegativeOffsetWithStandardSlot > msg.data.length) {
                revert RedstoneError.CalldataOverOrUnderFlow();
            }
            assembly {
                dataPackagesCount := calldataload(sub(calldatasize(), calldataNegativeOffsetWithStandardSlot))
            }
            return dataPackagesCount;
        }
    }

    function _extractDataPointValueAndDataFeedId(
        uint256 calldataNegativeOffsetForDataPackage,
        uint256 defaultDataPointValueByteSize,
        uint256 dataPointIndex
    ) private pure returns (bytes32 dataPointDataFeedId, uint256 dataPointValue) {
        uint256 negativeOffsetToDataPoints = calldataNegativeOffsetForDataPackage + DATA_PACKAGE_WITHOUT_DATA_POINTS_BS;
        uint256 dataPointNegativeOffset = negativeOffsetToDataPoints +
            ((1 + dataPointIndex) * ((defaultDataPointValueByteSize + DATA_POINT_SYMBOL_BS)));
        uint256 dataPointCalldataOffset = msg.data.length.sub(dataPointNegativeOffset);
        assembly {
            dataPointDataFeedId := calldataload(dataPointCalldataOffset)
            dataPointValue := calldataload(add(dataPointCalldataOffset, DATA_POINT_SYMBOL_BS))
        }
    }

    function proxyCalldata(
        address contractAddress,
        bytes memory encodedFunction,
        bool forwardValue
    ) internal returns (bytes memory) {
        bytes memory message = _prepareMessage(encodedFunction);

        (bool success, bytes memory result) = contractAddress.call{value: forwardValue ? msg.value : 0}(message);

        return _prepareReturnValue(success, result);
    }

    function proxyDelegateCalldata(address contractAddress, bytes memory encodedFunction) internal returns (bytes memory) {
        bytes memory message = _prepareMessage(encodedFunction);
        (bool success, bytes memory result) = contractAddress.delegatecall(message);
        return _prepareReturnValue(success, result);
    }

    function proxyCalldataView(address contractAddress, bytes memory encodedFunction) internal view returns (bytes memory) {
        bytes memory message = _prepareMessage(encodedFunction);
        (bool success, bytes memory result) = contractAddress.staticcall(message);
        return _prepareReturnValue(success, result);
    }

    function _prepareMessage(bytes memory encodedFunction) private pure returns (bytes memory) {
        uint256 encodedFunctionBytesCount = encodedFunction.length;
        uint256 redstonePayloadByteSize = _getRedstonePayloadByteSize();
        uint256 resultMessageByteSize = encodedFunctionBytesCount + redstonePayloadByteSize;

        if (redstonePayloadByteSize > msg.data.length) {
            revert RedstoneError.CalldataOverOrUnderFlow();
        }

        bytes memory message;

        assembly {
            message := mload(FREE_MEMORY_PTR) // sets message pointer to first free place in memory

            // Saving the byte size of the result message (it's a standard in EVM)
            mstore(message, resultMessageByteSize)

            // Copying function and its arguments
            for {
                let from := add(BYTES_ARR_LEN_VAR_BS, encodedFunction)
                let fromEnd := add(from, encodedFunctionBytesCount)
                let to := add(BYTES_ARR_LEN_VAR_BS, message)
            } lt(from, fromEnd) {
                from := add(from, STANDARD_SLOT_BS)
                to := add(to, STANDARD_SLOT_BS)
            } {
                // Copying data from encodedFunction to message (32 bytes at a time)
                mstore(to, mload(from))
            }

            // Copying redstone payload to the message bytes
            calldatacopy(
                add(message, add(BYTES_ARR_LEN_VAR_BS, encodedFunctionBytesCount)), // address
                sub(calldatasize(), redstonePayloadByteSize), // offset
                redstonePayloadByteSize // bytes length to copy
            )

            // Updating free memory pointer
            mstore(
                FREE_MEMORY_PTR,
                add(add(message, add(redstonePayloadByteSize, encodedFunctionBytesCount)), BYTES_ARR_LEN_VAR_BS)
            )
        }

        return message;
    }

    function _getRedstonePayloadByteSize() private pure returns (uint256) {
        uint256 calldataNegativeOffset = _extractByteSizeOfUnsignedMetadata();
        uint256 dataPackagesCount = _extractDataPackagesCountFromCalldata(calldataNegativeOffset);
        calldataNegativeOffset += DATA_PACKAGES_COUNT_BS;
        for (uint256 dataPackageIndex; dataPackageIndex < dataPackagesCount; ) {
            calldataNegativeOffset += _getDataPackageByteSize(calldataNegativeOffset);
            unchecked {
                dataPackageIndex++;
            }
        }

        return calldataNegativeOffset;
    }

    function _getDataPackageByteSize(uint256 calldataNegativeOffset) private pure returns (uint256) {
        (uint256 dataPointsCount, uint256 eachDataPointValueByteSize) = _extractDataPointsDetailsForDataPackage(
            calldataNegativeOffset
        );

        return dataPointsCount * (DATA_POINT_SYMBOL_BS + eachDataPointValueByteSize) + DATA_PACKAGE_WITHOUT_DATA_POINTS_BS;
    }

    function _prepareReturnValue(bool success, bytes memory result) internal pure returns (bytes memory) {
        if (!success) {
            if (result.length == 0) {
                revert RedstoneError.ProxyCalldataFailedWithoutErrMsg();
            } else {
                bool isStringErrorMessage;
                assembly {
                    let first32BytesOfResult := mload(add(result, BYTES_ARR_LEN_VAR_BS))
                    isStringErrorMessage := eq(first32BytesOfResult, STRING_ERR_MESSAGE_MASK)
                }

                if (isStringErrorMessage) {
                    string memory receivedErrMsg;
                    assembly {
                        receivedErrMsg := add(result, REVERT_MSG_OFFSET)
                    }
                    revert RedstoneError.ProxyCalldataFailedWithStringMessage(receivedErrMsg);
                } else {
                    revert RedstoneError.ProxyCalldataFailedWithCustomError(result);
                }
            }
        }

        return result;
    }
}
