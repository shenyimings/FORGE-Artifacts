// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IServerPriceFeed.sol";

contract ServerPriceFeed is IServerPriceFeed, Ownable {
    using SafeMath for uint256;
    bytes constant prefix = "\x19Ethereum Signed Message:\n32";

    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant ONE_USD = PRICE_PRECISION;
    uint256 public constant PRICE_VARIANCE_PRECISION = 10000;
    uint256 public constant BITMASK_32 = ~uint256(0) >> (256 - 32);

    //parameters for sign update
    uint256 public updateTimeTolerance = 15;
    mapping(address => bool) public isUpdater;
    mapping(address => uint256) private signUpdaterCode;
    mapping(address => uint256) private updateTime;

    //setting for token
    address[] public tokens;
    uint256[] public tokenPrecisions;
    mapping(address => uint256) public prices;
    mapping(address => uint256) public priceIndexLoc;


    //setting for spread
    mapping(address => uint256) public priceSpreadLong1Percent;
    mapping(address => uint256) public priceSpreadShort1Percent;
    mapping(address => uint256) public priceSpreadUpdateTime;


    //Counting for roud
    using Counters for Counters.Counter;
    Counters.Counter private _batchRoundId;
    mapping(address => Counters.Counter) private _tokenRoundID;

    //events
    event PriceUpdatedBatch(address token, uint256 ajustedAmount, uint256 batchRoundId);
    event PriceUpdatedSingle(address token, uint256 ajustedAmount, uint256 batchRoundId);

    event SpreadUpdatedLongSingle(address token, uint256 ajustedAmount);
    event SpreadUpdatedShortSingle(address token, uint256 ajustedAmount);

    modifier onlyUpdater() {
        require(isUpdater[msg.sender] || msg.sender == owner(), "FastPriceFeed: forbidden");
        _;
    }

    //settings for updater
    function setUpdater(address _account, bool _isActive) external onlyOwner {
        isUpdater[_account] = _isActive;
    }
    function setSignPrefixCode(address _updater, uint256 _setCode) external onlyOwner {
        signUpdaterCode[_updater] = _setCode;
    }

    //paras. for trade
    function setTimeTolerance(uint256 _tol) external onlyOwner {
        updateTimeTolerance = _tol;
    }
    function setBitTokens( address[] memory _tokens, uint256[] memory _tokenPrecisions) external onlyOwner {
        require(_tokens.length == _tokenPrecisions.length, "FastPriceFeed: invalid lengths");
        tokens = _tokens;
        tokenPrecisions = _tokenPrecisions;
        for(uint8 i = 0; i < _tokens.length; i++){
            priceIndexLoc[_tokens[i]] = i;
        }
    }

    //UPDATE functions for updater
    function setPriceSpreadFactor(address _token, uint256 _longPSF, uint256 _shortPSF, uint256 _timestamp) external override onlyUpdater {
        _setPriceSpreadFactor(_token, _longPSF, _shortPSF, _timestamp);
    }

    function setPricesWithBits(uint256[] memory _priceBits, uint256 _timestamp) external override onlyUpdater {
        _setPricesWithBits(_priceBits, _timestamp);
    }

    function setPricesWithBitsSingle(address _token, uint256 _priceBits, uint256 _timestamp) external override onlyUpdater {
        _setPricesWithBitsSingle(_token, _priceBits, _timestamp);
    }

    function setPriceSingle(address _token, uint256 _price, uint256 _timestamp) external override onlyUpdater {
        _setPricesSingle(_token, _price, _timestamp);
    }

    function setPricesWithBitsVerify(uint256[] memory _priceBits, uint256 _timestamp) external override onlyUpdater {
        _setPricesWithBits(_priceBits, _timestamp);
    }

    function setPricesWithBitsSingleVerify(address _token, uint256 _priceBits, uint256 _timestamp) external onlyUpdater {
        _setPricesWithBitsSingle(_token, _priceBits, _timestamp);
    }

    function setPriceSingleVerify(address _updater, address _token, uint256 _price, uint8 _priceType, uint256 _timestamp, bytes memory _updaterSignedMsg) external override returns (bool) {
        require(_priceType < 2, "unsupported price type");
        require(VerifySingle(_updater, _token, _price, _priceType, _timestamp, _updaterSignedMsg));

        if (_priceType == 0){
            _setPricesSingle(_token, _price, _timestamp);
        }
        else{
            _setPricesWithBitsSingle(_token, _price, _timestamp);
        }
        
        return true;
    }

    function setPriceBitsVerify(address _updater, uint256[] memory _priceBits, uint256 _timestamp, bytes memory _updaterSignedMsg) external override returns (bool) {
        require(VerifyBits(_updater, _priceBits, _timestamp, _updaterSignedMsg));
        _setPricesWithBits(_priceBits, _timestamp);
        return true;
    }

    function updateTokenInfo(address _updater, address _token, uint256[] memory _paras, uint256 _timestamp, bytes memory _updaterSignedMsg) external override returns (bool) {
        require(_paras.length == 3, "invalid parameters");
        require(VerifyFull(_updater, _token, _paras, _timestamp, _updaterSignedMsg));
        _setPricesWithBitsSingle(_token, _paras[0], _timestamp);
        _setPriceSpreadFactor(_token, _paras[1], _paras[2], _timestamp);
        return true;
    }



    //functions internal
    function _setPriceSpreadFactor(address _token, uint256 _longPSF, uint256 _shortPSF, uint256 _timestamp) internal {
        priceSpreadLong1Percent[_token] = _longPSF;
        priceSpreadShort1Percent[_token] = _shortPSF;
        priceSpreadUpdateTime[_token] = _timestamp;
    }

    function _setPricesWithBits(uint256[] memory _priceBits, uint256 _timestamp) private {
        uint256 roundId = _batchRoundId.current();
        _batchRoundId.increment();

        uint256 bitsMaxLength = 8;
        for (uint256 i = 0; i < _priceBits.length; i++) {
            uint256 priceBits = _priceBits[i];

            for (uint256 j = 0; j < bitsMaxLength; j++) {
                uint256 tokenIndex = i * bitsMaxLength + j;
                if (tokenIndex >= tokens.length) {
                    return;
                }

                uint256 startBit = 32 * j;
                uint256 price = (priceBits >> startBit) & BITMASK_32;
                address token = tokens[tokenIndex];
                require(_timestamp >= updateTime[token], "data out of time");
                updateTime[token] = _timestamp;
                uint256 tokenPrecision = tokenPrecisions[tokenIndex];
                uint256 adjustedPrice = price.mul(PRICE_PRECISION).div(
                    tokenPrecision
                );
                prices[token] = adjustedPrice;
                emit PriceUpdatedBatch(token, adjustedPrice, roundId);
            }
        }
    }

    function _setPricesWithBitsSingle(address _token, uint256 _priceBits, uint256 _timestamp) private {
        uint256 price = (_priceBits >> 0) & BITMASK_32;
        uint256 tokenPrecision = tokenPrecisions[priceIndexLoc[_token]];
        uint256 adjustedPrice = price.mul(PRICE_PRECISION).div(tokenPrecision);
        _setPricesSingle(_token, adjustedPrice, _timestamp);
    }

    function _setPricesSingle(address _token, uint256 _price, uint256 _timestamp) private {
        uint256 roundId = _tokenRoundID[_token].current();
        _tokenRoundID[_token].increment();
        require(_timestamp >= updateTime[_token], "data out of time");
        prices[_token] = _price;
        updateTime[_token] = _timestamp;
        emit PriceUpdatedSingle(_token, _price, roundId);
    }


    function updateWithSig(uint256[] memory _priceBits, uint256 _priceTimestamp,  address _updater, bytes memory _updaterSignedMsg) external onlyUpdater {
        require(VerifyBits(_updater, _priceBits, _priceTimestamp, _updaterSignedMsg), "Verification Failed");
        _setPricesWithBits(_priceBits, _priceTimestamp);
    }



    //public read
    function getPrice(address _token) public view override returns (uint256, uint256) {
        return (prices[_token], updateTime[_token]);
    }

    function getPriceSpreadFactoe(address _token) public view override returns (uint256, uint256, uint256) {
        return(priceSpreadLong1Percent[_token],
                priceSpreadShort1Percent[_token],
                priceSpreadUpdateTime[_token]);
    }

    function VerifyFull(address _updater, address _token, uint256[] memory _priceBits, uint256 _priceTimestamp, bytes memory _updaterSignedMsg) public view returns (bool) {
        if (updateTimeTolerance > 0)
            require(_priceTimestamp <= block.timestamp && block.timestamp.sub(_priceTimestamp) < updateTimeTolerance, "time tollarance reached.");
        bytes memory content = abi.encodePacked(signUpdaterCode[_updater], _updater, _token, _priceTimestamp);
        for(uint8 i = 0; i < _priceBits.length; i++){
            content =  abi.encodePacked(content, _priceBits[i]);//, "."
        }
        bytes32 _calHash = keccak256(content);
        bytes32 ethSignedHash = keccak256(abi.encodePacked(prefix, _calHash));
        return isUpdater[recoverSigner(ethSignedHash, _updaterSignedMsg)];
    }

    function VerifyBits(address _updater, uint256[] memory _priceBits, uint256 _priceTimestamp, bytes memory _updaterSignedMsg) public view returns (bool) {
        if (updateTimeTolerance > 0)
            require(_priceTimestamp <= block.timestamp && block.timestamp.sub(_priceTimestamp) < updateTimeTolerance, "time tollarance reached.");
        bytes memory content = abi.encodePacked(signUpdaterCode[_updater], _updater, _priceTimestamp);
        for(uint8 i = 0; i < _priceBits.length; i++){
            content =  abi.encodePacked(content, _priceBits[i]);//, "."
        }
        bytes32 _calHash = keccak256(content);
        bytes32 ethSignedHash = keccak256(abi.encodePacked(prefix, _calHash));
        return isUpdater[recoverSigner(ethSignedHash, _updaterSignedMsg)];
    }


    function VerifySingle(address _updater, address _token, uint256 _price, uint8 _priceType, uint256 _priceTimestamp, bytes memory _updaterSignedMsg) public view returns (bool) {
        if (updateTimeTolerance > 0)
            require(_priceTimestamp <= block.timestamp && block.timestamp.sub(_priceTimestamp) < updateTimeTolerance, "time tollarance reached.");
        bytes memory content = abi.encodePacked(signUpdaterCode[_updater], _updater, _priceTimestamp, _token, _price, _priceType);
        bytes32 _calHash = keccak256(content);
        bytes32 ethSignedHash = keccak256(abi.encodePacked(prefix, _calHash));
        return isUpdater[recoverSigner(ethSignedHash, _updaterSignedMsg)];
    }

    //code for verify
    function VerifyMessage(bytes32 _hashedMessage, uint8 _v, bytes32 _r, bytes32 _s) public pure returns (address) {
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        return signer;
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v){
        require(sig.length == 65, "invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address){
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

}
