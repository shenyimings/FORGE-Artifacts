// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';

import './FoldingAccount.sol';
import './interfaces/IFoldingAccountOwnerProvider.sol';
import './interfaces/IFoldingConnectorProvider.sol';
import './interfaces/ILendingPlatformAdapterProvider.sol';
import './interfaces/IExchangerAdapterProvider.sol';
import './interfaces/ICTokenProvider.sol';
import './FodlNFT.sol';

contract FoldingRegistry is
    Initializable,
    OwnableUpgradeable,
    IFoldingAccountOwnerProvider,
    IFoldingConnectorProvider,
    ILendingPlatformAdapterProvider,
    ICTokenProvider,
    IExchangerAdapterProvider
{
    FodlNFT public fodlNFT;

    function initialize(address fodlNFT_) public virtual initializer {
        require(fodlNFT_ != address(0), 'ICP0');
        __Ownable_init_unchained();
        fodlNFT = FodlNFT(fodlNFT_);
    }

    function version() external pure virtual returns (uint8) {
        return 1;
    }

    mapping(address => uint256) internal nonces;

    /**
     * @dev create2 is needed in order to be able to predict the folding
     * account address in a way that does not depend on the nonce of the sender.
     * This is because prior to creating the account, the user will need to approve
     * tokens to be sent to it. Thus we keep internal contract nonces so that this salt
     * is always unique for every sender without compromising UX.
     */
    function createAccount() public virtual returns (address) {
        bytes memory bytecode = type(FoldingAccount).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(address(this), address(fodlNFT)));

        uint256 salt = uint256(keccak256(abi.encodePacked(msg.sender, nonces[msg.sender])));
        nonces[msg.sender] = nonces[msg.sender] + 1;

        address account;
        uint256 size;
        assembly {
            account := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            size := extcodesize(account)
        }
        require(size > 0, 'FR1');

        fodlNFT.mint(msg.sender, uint256(account));

        return account;
    }

    function accountOwner(address account) external view virtual override returns (address) {
        return fodlNFT.ownerOf(uint256(account));
    }

    /// @notice Fallback function creates an account and forwards the call
    function _fallback() internal virtual {
        address createdAccount = createAccount();
        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := call(gas(), createdAccount, callvalue(), 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    fallback() external payable {
        _fallback();
    }

    /// @dev Don't specify state mutability for upgradability.
    function _receive() internal virtual {
        revert('FR13');
    }

    receive() external payable {
        _receive();
    }

    // ********** Folding Connector Registration and IFoldingConnectorProvider **********

    event ImplementationAdded(address implementation, bytes4[] signatures);
    event ImplementationRemoved(bytes4[] signatures);

    /// @dev mapping from function signatures to the connector that implements them
    mapping(bytes4 => address) internal sigImplementations;

    function addImplementation(address _implementation, bytes4[] calldata _sigs) public virtual onlyOwner {
        require(_implementation != address(0), 'FR14');
        for (uint256 i = 0; i < _sigs.length; i++) {
            bytes4 _sig = _sigs[i];
            sigImplementations[_sig] = _implementation;
        }
        emit ImplementationAdded(_implementation, _sigs);
    }

    function removeImplementation(bytes4[] memory sigs) public virtual onlyOwner {
        emit ImplementationRemoved(sigs);

        for (uint256 i = 0; i < sigs.length; i++) {
            bytes4 sig = sigs[i];
            delete sigImplementations[sig];
        }
    }

    function getImplementation(bytes4 _sig) external view virtual override returns (address implementation) {
        implementation = sigImplementations[_sig];
        require(implementation != address(0), 'FR2');
    }

    // ********** Lending Platform Adapter Registry and ILendingPlatformAdapterProvider **********

    mapping(address => address) internal platformAdapters;

    event PlatformAdapterLinkUpdated(address platform, address adapter);

    function addPlatformWithAdapter(address platform, address adapter) public virtual onlyOwner {
        require(platform != address(0), 'FR14');
        require(platformAdapters[platform] == address(0), 'FR3');
        platformAdapters[platform] = adapter;
        emit PlatformAdapterLinkUpdated(platform, adapter);
    }

    function addBatchPlatformsWithAdapter(address[] memory platforms, address adapter) external virtual onlyOwner {
        require(platforms.length > 0, 'FR4');
        for (uint256 i = 0; i < platforms.length; i++) {
            addPlatformWithAdapter(platforms[i], adapter);
        }
    }

    function changePlatformAdapter(address platform, address newAdapter) external virtual onlyOwner {
        require(platform != address(0), 'FR14');
        require(platformAdapters[platform] != address(0), 'FR5');
        platformAdapters[platform] = newAdapter;
        emit PlatformAdapterLinkUpdated(platform, newAdapter);
    }

    function removePlatform(address platform) external virtual onlyOwner {
        require(platformAdapters[platform] != address(0), 'FR5');
        delete platformAdapters[platform];
        emit PlatformAdapterLinkUpdated(platform, address(0));
    }

    function getPlatformAdapter(address platform) external view virtual override returns (address adapter) {
        adapter = platformAdapters[platform];
        require(adapter != address(0), 'FR6');
    }

    // ********** Lending Platform Token Mappings and ICTokenProvider **********

    mapping(address => mapping(address => address)) internal tokensOnPlatforms;

    event TokenOnPlatformUpdated(address platform, address token, address syntheticToken);

    function addCTokenOnPlatform(
        address platform,
        address token,
        address synthToken
    ) external virtual onlyOwner {
        require(platform != address(0), 'FR14');
        require(token != address(0), 'FR14');
        require(tokensOnPlatforms[platform][token] == address(0), 'FR7');
        tokensOnPlatforms[platform][token] = synthToken;
        emit TokenOnPlatformUpdated(platform, token, synthToken);
    }

    function removeCTokenFromPlatform(address platform, address token) external virtual onlyOwner {
        require(tokensOnPlatforms[platform][token] != address(0), 'FR8');
        delete tokensOnPlatforms[platform][token];
        emit TokenOnPlatformUpdated(platform, token, address(0));
    }

    function getCToken(address platform, address token) external view virtual override returns (address cToken) {
        cToken = tokensOnPlatforms[platform][token];
        require(cToken != address(0), 'FR9');
    }

    // ********** Exchanger Adapter Registry and IExchangerAdapterProvider **********

    mapping(bytes1 => address) internal exchangerAdapters;

    event ExchangerAdapterLinkUpdated(bytes1 flag, address adapter);

    function addExchangerWithAdapter(bytes1 flag, address adapter) external virtual onlyOwner {
        require(adapter != address(0), 'FR14');
        require(exchangerAdapters[flag] == address(0), 'FR10');
        exchangerAdapters[flag] = adapter;
        emit ExchangerAdapterLinkUpdated(flag, adapter);
    }

    function changeExchangerAdapter(bytes1 flag, address newAdapter) external virtual onlyOwner {
        require(newAdapter != address(0), 'FR14');
        require(exchangerAdapters[flag] != address(0), 'FR11');
        exchangerAdapters[flag] = newAdapter;
        emit ExchangerAdapterLinkUpdated(flag, newAdapter);
    }

    function removeExchanger(bytes1 flag) external virtual onlyOwner {
        require(exchangerAdapters[flag] != address(0), 'FR11');
        delete exchangerAdapters[flag];
        emit ExchangerAdapterLinkUpdated(flag, address(0));
    }

    function getExchangerAdapter(bytes1 flag) external view virtual override returns (address adapter) {
        adapter = exchangerAdapters[flag];
        require(adapter != address(0), 'FR12');
    }
}
