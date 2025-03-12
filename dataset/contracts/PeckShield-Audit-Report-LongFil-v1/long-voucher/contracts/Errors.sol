// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library Errors {
    // common
    string public constant INVALID_PARAMETER = "00";
    string public constant ZERO_ADDRESS = "01";
    string public constant INDEX_EXCEEDS = "02";
    string public constant NOT_OWNER = "03";
    string public constant INSUFFICIENT_BALANCE = "04";
    string public constant SEND_ERROR = "09";

    string public constant NOT_OWNER_NOR_APPROVED = "10";
    string public constant APPROVE_TO_OWNER = "11";
    string public constant APPROVE_TO_CALLER = "12";
    string public constant INSUFFICIENT_ALLOWANCE = "13";
    string public constant INVALID_TOKEN_ID = "14";
    string public constant TOKEN_ALREADY_MINTED = "15";
    string public constant CROSS_SLOT = "16";
    string public constant RECEIVER_REJECTED = "17";
    string public constant NON_ERC721RECEIVER = "18";
    string public constant SLOT_NOT_EXISTS = "19";
    string public constant NOT_SLOT_MANAGER_ROLE = "20";
    string public constant NOT_MANAGER_OF_SLOT = "21";
    // string public constant NOT_SLOT_MANAGER_TYPE = "22";
    string public constant SLOT_MANAGER_ALREADY_EXISTS = "23";

    string public constant DUPLICATED_PRODUCT_ID = "30";
    string public constant NOT_AVAILABLE_PRODUCT_ID = "31";
    string public constant BAD_TOTALQUOTA = "32";
    string public constant BAD_MINSUBSCRIPTIONAMOUNT = "33";
    string public constant BAD_BEGINSUBSCRIPTIONBLOCK = "34";
    string public constant BAD_ENDSUBSCRIPTIONBLOCK = "35";
    string public constant ILLEGAL_CALLER = "36";
    string public constant EXCEEDS_TOTALQUOTA = "37";
    string public constant LESS_THAN_MINSUBSCRIPTIONAMOUNT = "38";
    string public constant NOT_REDEEMABLE_AT_PRESENT = "40";
    string public constant PRODUCT_NOT_EXISTS = "41";
    string public constant NOT_SUBSCRIBER = "42";
    string public constant INVALID_PRODUCT_STAGE = "43";
    string public constant TRANSFORM_CONTROL = "44";
    string public constant RECOMMENDATION_CENTER = "45";
}
