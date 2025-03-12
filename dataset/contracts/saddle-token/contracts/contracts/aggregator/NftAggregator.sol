// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./TransferHelper.sol";
import "./MarketplaceRegistry.sol";

error InactiveMarket();
error MAX_FEE_EXCEEDED();
error TradingNotOpen();
error UNMET_BASE_FEE();

interface INftProfile {
    function ownerOf(uint256 _tokenId) external view returns (address);
}

/// @title A nft marketplace aggregator
/// @notice This contract allows users to trade with multiple nft marketplaces on EVM based chains
contract NftAggregator is Initializable, ReentrancyGuardUpgradeable, UUPSUpgradeable, TransferHelper {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    MarketplaceRegistry public marketplaceRegistry;
    uint256 public baseFee; // denominated in wei
    bool public openForTrades;
    bool public extraBool;
    uint256 public percentFeeToDao;
    address public converter;
    address public nftProfile;
    address public dao;
    address public pendingOwner;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event NewConverter(address indexed _new);
    event NewNftProfile(address indexed _new);
    event NewOwner(address indexed _new);
    event NewDao(address indexed _new);

    /**
     * @notice used for gas optimization
     */
    function _onlyOwner() private view {
        require(msg.sender == owner);
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function initialize(address _marketRegistry, address _cryptoPunk, address _mooncat) public initializer {
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __TransferHelper_init(_cryptoPunk, _mooncat);

        owner = msg.sender;
        marketplaceRegistry = MarketplaceRegistry(_marketRegistry);
        percentFeeToDao = 0;
        baseFee = 0;
        openForTrades = true;
        extraBool = true;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                                OWNER FNs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice rescueETH is an emergency function used to rescue ETH stuck in the contract
     */
    function rescueETH(address recipient) external onlyOwner {
        _transferEth(recipient, address(this).balance);
    }

    /**
     * @notice rescueERC20 is an emergency function used to rescue ERC20s stuck in the contract
     */
    function rescueERC20(address asset, address recipient) external onlyOwner {
        // bytes4(keccak256('transfer(address,uint256)')) == 0xa9059cbb
        asset.call(abi.encodeWithSelector(0xa9059cbb, recipient, IERC20Upgradeable(asset).balanceOf(address(this))));
    }

    /**
     * @notice rescueERC721 is an emergency function used to rescue 721s stuck in the contract
     */
    function rescueERC721(
        address asset,
        uint256[] calldata ids,
        address recipient
    ) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            IERC721Upgradeable(asset).transferFrom(address(this), recipient, ids[i]);
        }
    }

    /**
     * @notice rescueERC1155 is an emergency function used to rescue 1155s stuck in the contract
     */
    function rescueERC1155(
        address asset,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        address recipient
    ) external onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            IERC1155Upgradeable(asset).safeTransferFrom(address(this), recipient, ids[i], amounts[i], "");
        }
    }

    /**
     * @notice rescueMooncat is an emergency function used to rescue a mooncat in the contract
     * @param erc721Details is a struct representing the tokenId, recipient and token contract
     */
    function rescueMooncat(
        ERC721Details calldata erc721Details
    ) external onlyOwner {
        _transferMoonCat(erc721Details);
    }

    /**
     * @notice rescuePunk is an emergency function used to rescue a punk in the contract
     * @param erc721Details is a struct representing the tokenId, recipient and token contract
     */
    function rescuePunk(
        ERC721Details calldata erc721Details
    ) external onlyOwner {
        _transferCryptoPunk(erc721Details);
    }

    /**
     * @notice setOwner sets a new pending owner of the aggregator (step 1 / 2)
     * @param _new represents the address of the new pending owner
     */
    function setOwner(address _new) external onlyOwner {
        pendingOwner = _new;
    }

    /**
     * @notice acceptOwnership allows the pending owner to prove ownership
       and accept the request (step 2 / 2)
     */
    function acceptOwnership() external {
        require(msg.sender == pendingOwner);
        owner = msg.sender;
        emit NewOwner(msg.sender);
    }

    /**
     * @notice setConverter sets the address of the converter contract/library
       used for converting assets into other assets
     * @param _new represents the address of the new converter
     */
    function setConverter(address _new) external onlyOwner {
        converter = _new;
        emit NewConverter(_new);
    }

    /**
     * @notice setNftProfile sets the address of the NFT.com Profile
       which is primarily used for affiliate fee disbursements
     * @param _new represents the address of the NFT.com Profile
     */
    function setNftProfile(address _new) external onlyOwner {
        nftProfile = _new;
        emit NewNftProfile(_new);
    }

    /**
     * @notice setDao sets the address of the DAO, or the recipient of the DaoFee
     * @param _new represents the address of the new DAO
     */
    function setDao(address _new) external onlyOwner {
        dao = _new;
        emit NewDao(_new);
    }

    /**
     * @notice setDaoFee sets a percent fee allocated when fee > 0. The max fee is 10000, which 
       represents 100% of the fee going torwards the DAO. If the DAO Fee = 0, 0% of the fee goes towards
       the DAO.
     * @param _percentFeeToDao represents a number between 0 - 10000, where 100 = 100%
     */
    function setDaoFee(uint256 _percentFeeToDao) external onlyOwner {
        if (_percentFeeToDao > 10000) revert MAX_FEE_EXCEEDED();
        percentFeeToDao = _percentFeeToDao;
    }

    /**
     * @notice setBaseFee sets the minimum fee in WEI required for the DAO / owner when fees > 0.
       We may optionally change this in the future to require fees > 0, but that is TBD.
     * @param _baseFee is the minimum fee in WEI required for transactions where fees > 0
     */
    function setBaseFee(uint256 _baseFee) external onlyOwner {
        baseFee = _baseFee;
    }

    /**
     * @notice setOpenForTrades is an owner function that toggles trading ability
     * @param _openForTrades is a boolean representing if trading is allowed
     */
    function setOpenForTrades(bool _openForTrades) external onlyOwner {
        openForTrades = _openForTrades;
    }

    /**
     * @notice setOneTimeApproval is needed to set ERC20 token approvals from this contract to other contracts.
       The primary use case is essentially whitelisting ERC20s passed to this contract when trading. Other exchanges
       such as Looksrare, Seaport and more require allowance / approvals on ERC20s in order to allow token transfers.
       This function is gated by owner and thus is manually called to approve ERC20s to each exchange
     * @param _approvals is an array of structs containing an ERC20 token contract, an operator, and an amount.
     */
    function setOneTimeApproval(
        Approvals[] calldata _approvals
    ) external onlyOwner {
        for (uint256 i = 0; i < _approvals.length;) {
            IERC20Upgradeable(_approvals[i].token).approve(
                _approvals[i].operator,
                _approvals[i].amount
            );
            unchecked {
                ++i;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FNs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice _collectFee is a fee collection helper function that allows NFT.com profile holders to earn affiliate
       fees in the form of ETH, in addition to the owner of this contract (could be an entity, DAO, etc)
     * @param _feeDetails represents an affiliate token id (nft.com profile tokenId) and a fee represented in wei
     */
    function _collectFee(
        FeeDetails calldata _feeDetails // [affiliateTokenId, ETH fee in Wei]
    ) internal {
        uint256 _profileTokenId = _feeDetails._profileTokenId;
        uint256 _wei = _feeDetails._wei;

        if (_wei != 0) {
            uint256 _weiToDao = _wei * (percentFeeToDao) / 10000;
            if (_weiToDao < baseFee) revert UNMET_BASE_FEE();

            if (percentFeeToDao != 0) {
                _transferEth(dao, _weiToDao);
            }

            _transferEth(INftProfile(nftProfile).ownerOf(_profileTokenId), _wei - _weiToDao);
        }
    }

    /**
     * @notice _trade is an internal helper function that loops through the various trade
       execution orders, checks against the status on our marketplace registry, and then proceeds
       to execute the encoded function call, whether it is a library call or a contract call.

       We also check the final call result and return the error to the client if any error is found.
     * @param _tradeDetails is an array of bytes, containing encoded execution logic
     */
    function _trade(
        TradeDetails[] memory _tradeDetails
    ) internal {
        for (uint256 i = 0; i < _tradeDetails.length; ) {
            (address _proxy, bool _isLib, bool _isActive) = marketplaceRegistry.marketplaces(_tradeDetails[i].marketId);
            if (!_isActive) revert InactiveMarket();

            (bool success, ) = _isLib
                ? _proxy.delegatecall(_tradeDetails[i].tradeData)
                : _proxy.call{ value: _tradeDetails[i].value }(_tradeDetails[i].tradeData);

            _checkCallResult(success);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice _conversionHelper is an internal function that delegate calls our conversion
       helper contract. The idea is to allow users to swap between currencies easily without
       having to go to a third party site. Much of the logic for handling the trading cases will
       be driven off-chain by our server / client, which will pass in the parameters here and 
       execute on chain.
     * @param _conversionDetails is an array of bytes, containing encoded execution logic
     */
    function _conversionHelper(
        bytes[] memory _conversionDetails
    ) internal {
        for (uint256 i = 0; i < _conversionDetails.length; i++) {
            (bool success, ) = converter.delegatecall(_conversionDetails[i]);
            _checkCallResult(success);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FNs
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice batchTradeWithETH is an external function that allows users to only pass in ETH
       to trade and interact with live listings found on Marketplace Registry
     * @param tradeDetails is an array of information about marketplace specific actions.
       Information includes marketId (which marketplace to interact with via MarketplaceRegistry),
       value (ETH payable value sent), and tradeData, which is represented in bytes
     * @param tradeInfo is an additional struct primarily used to combine additional parameters
       such that we don't exceed the call stack. It includes parameters related to conversion details,
       (which is an array of bytes that allows us to potentially swap different currencies in situ),
       dustTokens, which returns dust ERC20 tokens + ETH specified at the end of the call, and feeDetails,
       which can be thought of any additional fees optionally charged in the future as well as affiliate sponsor fees
       paid to NFT.com profile affiliate sales
     */
    function batchTradeWithETH(
        TradeDetails[] calldata tradeDetails,
        MultiAssetInfo calldata tradeInfo
    )
        external
        payable
        nonReentrant
    {
        if (!openForTrades) revert TradingNotOpen();

        _collectFee(tradeInfo.feeDetails);
        _conversionHelper(tradeInfo.conversionDetails);
        _trade(tradeDetails);
        _returnDust(tradeInfo.dustTokens);
    }

    /**
     * @notice batchTrade is an external function that allows users to trade and buy existing
       nft listings on our partner marketplaces
     * @param erc20Details is a struct containing fields for array of erc20s and amounts
     * @param tradeDetails is an array of information about marketplace specific actions.
       Information includes marketId (which marketplace to interact with via MarketplaceRegistry),
       value (ETH payable value sent), and tradeData, which is represented in bytes
     * @param tradeInfo is an additional struct primarily used to combine additional parameters
       such that we don't exceed the call stack. It includes parameters related to conversion details,
       (which is an array of bytes that allows us to potentially swap different currencies in situ),
       dustTokens, which returns dust ERC20 tokens + ETH specified at the end of the call, and feeDetails,
       which can be thought of any additional fees optionally charged in the future as well as affiliate sponsor fees
       paid to NFT.com profile affiliate sales
     */
    function batchTrade(
        ERC20Details calldata erc20Details,
        TradeDetails[] calldata tradeDetails,
        MultiAssetInfo calldata tradeInfo
    ) external payable nonReentrant {
        if (!openForTrades) revert TradingNotOpen();

        for (uint256 i = 0; i < erc20Details.tokenAddrs.length; ) {
            // bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
            erc20Details.tokenAddrs[i].call(
                abi.encodeWithSelector(0x23b872dd, msg.sender, address(this), erc20Details.amounts[i])
            );

            unchecked {
                ++i;
            }
        }

        _collectFee(tradeInfo.feeDetails);
        _conversionHelper(tradeInfo.conversionDetails);
        _trade(tradeDetails);
        _returnDust(tradeInfo.dustTokens);
    }

    /**
     * @notice multiAssetSwap allows transfers and trades with all asset types
       including erc1155s, erc721s, erc20s and ETH
     * @param erc20Details is a struct containing fields for array of erc20s and amounts
     * @param erc721Details is an array of erc721s, including tokenId, recipient and token contract
     * @param erc1155Details is an array of erc1155s, including tokenIds, amounts and token contract.
       Recipient is address(this)
     * @param tradeDetails is an array of information about marketplace specific actions
       Information includes marketId (which marketplace to interact with via MarketplaceRegistry),
       value (ETH payable value sent), and tradeData, which is represented in bytes
     * @param tradeInfo is an additional struct primarily used to combine additional parameters
       such that we don't exceed the call stack. It includes parameters related to conversion details,
       (which is an array of bytes that allows us to potentially swap different currencies in situ),
       dustTokens, which returns dust ERC20 tokens + ETH specified at the end of the call, and feeDetails,
       which can be thought of any additional fees optionally charged in the future as well as affiliate sponsor fees
       paid to NFT.com profile affiliate sales
     */
    function multiAssetSwap(
        ERC20Details calldata erc20Details,
        ERC721Details[] calldata erc721Details,
        ERC1155Details[] calldata erc1155Details,
        TradeDetails[] calldata tradeDetails,
        MultiAssetInfo calldata tradeInfo
    ) payable external nonReentrant {
        if (!openForTrades) revert TradingNotOpen();
        
        _collectFee(tradeInfo.feeDetails);

        _transferFromHelper(
            erc20Details,
            erc721Details,
            erc1155Details
        );

        _conversionHelper(tradeInfo.conversionDetails);
        _trade(tradeDetails);
        _returnDust(tradeInfo.dustTokens);
    }
}