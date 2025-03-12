// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Aspida's minter module
 * @author Aspida engineer
 */
abstract contract Minter {
    /**
     * @notice Mapping of token minters to corresponding token mintage cap
     * @dev  The mint cap of the token minter, will be checked in minting
     *  -1 means there is no limit on the cap
     *  0 means the token token can not be mint any more
     */
    mapping(address => uint256) internal mintCaps_;

    /**
     * @notice Mapping of token miners and corresponding token minting volume
     */
    mapping(address => uint256) internal mintAmounts_;

    /// @dev Emitted when `mintCap` changes.
    event SetMinterCap(address minter, uint256 mintCap);

    /// @dev Emitted when `mintAmount` increase.
    event IncreaseMintAmount(address minter, uint256 increaseAmount, uint256 mintAmount);

    /// @dev Emitted when `mintAmount` decrease.
    event DecreaseMintAmount(address minter, uint256 decreaseAmount, uint256 mintAmount);

    /**
     * @dev Throws an exception if the mint cap is exceeded.
     */
    modifier checkMintCap(uint256 _increaseAmount) {
        _checkMintCap(msg.sender, _increaseAmount);
        _;
    }

    /**
     * @dev Set `mintCap`.
     * @param _minter Minter address
     * @param _mintCap The mint caps to set for minter
     */
    function _setMinterCapInternal(address _minter, uint256 _mintCap) internal virtual {
        require(_minter != address(0), "_setMinterCapInternal: Minter the zero address");
        require(_mintCap != mintCaps_[_minter], "_setMinterCapInternal: Cannot set the same value");
        mintCaps_[_minter] = _mintCap;
        emit SetMinterCap(_minter, _mintCap);
    }

    /**
     * @dev Increase minter `mintAmount`.
     * @param _minter Minter address
     * @param _amount Increase Amount
     */
    function _increaseMintAmount(address _minter, uint256 _amount) internal virtual {
        mintAmounts_[_minter] += _amount;
        emit IncreaseMintAmount(_minter, _amount, mintAmounts_[_minter]);
    }

    /**
     * @dev Decrease minter `mintAmount`.
     * @param _minter Minter address
     * @param _amount Decrease Amount
     */
    function _decreaseMintAmount(address _minter, uint256 _amount) internal virtual {
        mintAmounts_[_minter] -= _amount;
        emit DecreaseMintAmount(_minter, _amount, mintAmounts_[_minter]);
    }

    /**
     * @dev Checks if the mint cap is reached for a minter.
     * @param _minter The address of the minter.
     * @param _amount The amount to be minted.
     * Throws an exception if the mint cap is reached.
     */
    function _checkMintCap(address _minter, uint256 _amount) internal virtual {
        require(mintAmounts_[_minter] + _amount <= mintCaps_[_minter], "_checkMintCap: Minter mint capacity reached");
    }

    /**
     * @dev Mint cap of the minter
     * @return _minter Minter address
     */
    function mintCap(address _minter) external view returns (uint256) {
        return mintCaps_[_minter];
    }

    /**
     * @dev Mint amount of the minter
     * @return _minter Minter address
     */
    function mintAmount(address _minter) external view returns (uint256) {
        return mintAmounts_[_minter];
    }
}
