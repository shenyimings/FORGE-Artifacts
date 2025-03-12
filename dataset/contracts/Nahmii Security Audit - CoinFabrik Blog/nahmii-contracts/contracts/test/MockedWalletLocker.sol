/*
 * Hubii Nahmii
 *
 * Compliant with the Hubii Nahmii specification v0.12.
 *
 * Copyright (C) 2017-2018 Hubii AS
 */

pragma solidity ^0.4.25;

/**
 * @title MockedWalletLocker
 * @notice Mocked implementation of wallet locker contract
 */
contract MockedWalletLocker {
    //
    // Types
    // -----------------------------------------------------------------------------------------------------------------
    struct FungibleLock {
        address lockedWallet;
        address lockerWallet;
        int256 amount;
        address currencyCt;
        uint256 currencyId;
    }

    struct NonFungibleLock {
        address lockedWallet;
        address lockerWallet;
        int256[] ids;
        address currencyCt;
        uint256 currencyId;
    }

    struct Unlock {
        address lockedWallet;
        address lockerWallet;
        address currencyCt;
        uint256 currencyId;
    }

    //
    // Variables
    // -----------------------------------------------------------------------------------------------------------------
    FungibleLock[] public fungibleLocks;
    Unlock[] public fungibleUnlocks;
    NonFungibleLock[] public nonFungibleLocks;
    Unlock[] public nonFungibleUnlocks;

    address[] public lockedWallets;
    address[] public unlockedWallets;

    bool public locked;
    int256 public _lockedAmount;
    uint256 public _lockedIdsCount;
    int256[] public _lockedIdsByIndices;

    //
    // Events
    // -----------------------------------------------------------------------------------------------------------------
    event LockFungibleByProxyEvent(address lockedWallet, address lockerWallet, int256 amount,
        address currencyCt, uint256 currencyId);
    event LockNonFungibleByProxyEvent(address lockedWallet, address lockerWallet, int256[] ids,
        address currencyCt, uint256 currencyId);
    event UnlockFungibleEvent(address lockedWallet, address lockerWallet, address currencyCt,
        uint256 currencyId);
    event UnlockFungibleByProxyEvent(address lockedWallet, address lockerWallet, address currencyCt,
        uint256 currencyId);
    event UnlockNonFungibleEvent(address lockedWallet, address lockerWallet, address currencyCt,
        uint256 currencyId);
    event UnlockNonFungibleByProxyEvent(address lockedWallet, address lockerWallet, address currencyCt,
        uint256 currencyId);

    //
    // Functions
    // -----------------------------------------------------------------------------------------------------------------
    function _reset()
    public
    {
        fungibleLocks.length = 0;
        fungibleUnlocks.length = 0;
        nonFungibleLocks.length = 0;
        nonFungibleUnlocks.length = 0;
        lockedWallets.length = 0;
        unlockedWallets.length = 0;
        locked = false;
        _lockedAmount = 0;
        _lockedIdsCount = 0;
        _lockedIdsByIndices.length = 0;
    }

    function lockFungibleByProxy(address lockedWallet, address lockerWallet, int256 amount,
        address currencyCt, uint256 currencyId)
    public
    {
        fungibleLocks.push(FungibleLock(lockedWallet, lockerWallet, amount, currencyCt, currencyId));
        lockedWallets.push(lockedWallet);
        emit LockFungibleByProxyEvent(lockedWallet, lockerWallet, amount, currencyCt, currencyId);
    }

    function lockNonFungibleByProxy(address lockedWallet, address lockerWallet, int256[] ids,
        address currencyCt, uint256 currencyId)
    public
    {
        nonFungibleLocks.push(NonFungibleLock(lockedWallet, lockerWallet, ids, currencyCt, currencyId));
        lockedWallets.push(lockedWallet);
        emit LockNonFungibleByProxyEvent(lockedWallet, lockerWallet, ids, currencyCt, currencyId);
    }

    function unlockFungible(address lockedWallet, address lockerWallet,
        address currencyCt, uint256 currencyId)
    public
    {
        fungibleUnlocks.push(Unlock(lockedWallet, lockerWallet, currencyCt, currencyId));
        unlockedWallets.push(lockedWallet);
        emit UnlockFungibleEvent(lockedWallet, lockerWallet, currencyCt, currencyId);
    }

    function unlockFungibleByProxy(address lockedWallet, address lockerWallet,
        address currencyCt, uint256 currencyId)
    public
    {
        fungibleUnlocks.push(Unlock(lockedWallet, lockerWallet, currencyCt, currencyId));
        unlockedWallets.push(lockedWallet);
        emit UnlockFungibleByProxyEvent(lockedWallet, lockerWallet, currencyCt, currencyId);
    }

    function unlockNonFungible(address lockedWallet, address lockerWallet,
        address currencyCt, uint256 currencyId)
    public
    {
        nonFungibleUnlocks.push(Unlock(lockedWallet, lockerWallet, currencyCt, currencyId));
        unlockedWallets.push(lockedWallet);
        emit UnlockNonFungibleEvent(lockedWallet, lockerWallet, currencyCt, currencyId);
    }

    function unlockNonFungibleByProxy(address lockedWallet, address lockerWallet,
        address currencyCt, uint256 currencyId)
    public
    {
        nonFungibleUnlocks.push(Unlock(lockedWallet, lockerWallet, currencyCt, currencyId));
        unlockedWallets.push(lockedWallet);
        emit UnlockNonFungibleByProxyEvent(lockedWallet, lockerWallet, currencyCt, currencyId);
    }

    function _lockedWalletsCount()
    public
    view
    returns (uint256)
    {
        return lockedWallets.length;
    }

    function _unlockedWalletsCount()
    public
    view
    returns (uint256)
    {
        return unlockedWallets.length;
    }

    function _fungibleLocksCount()
    public
    view
    returns (uint256)
    {
        return fungibleLocks.length;
    }

    function _fungibleUnlocksCount()
    public
    view
    returns (uint256)
    {
        return fungibleUnlocks.length;
    }

    function _nonFungibleLocksCount()
    public
    view
    returns (uint256)
    {
        return nonFungibleLocks.length;
    }

    function _nonFungibleUnlocksCount()
    public
    view
    returns (uint256)
    {
        return nonFungibleUnlocks.length;
    }

    function isLocked(address)
    public
    view
    returns (bool)
    {
        return locked;
    }

    function isLocked(address, address, uint256)
    public
    view
    returns (bool)
    {
        return locked;
    }

    function isLocked(address, address, address, uint256)
    public
    view
    returns (bool)
    {
        return locked;
    }

    function _setLocked(bool _locked)
    public
    {
        locked = _locked;
    }

    function lockedAmount(address, address, address, uint256)
    public
    view
    returns (int256)
    {
        return _lockedAmount;
    }

    function _setLockedAmount(int256 amount)
    public
    {
        _lockedAmount = amount;
    }

    function lockedIdsCount(address, address, address, uint256)
    public
    view
    returns (uint256)
    {
        return _lockedIdsCount;
    }

    function _setLockedIdsCount(uint256 count)
    public
    {
        _lockedIdsCount = count;
    }

    function lockedIdsByIndices(address, address, address, uint256, uint256, uint256)
    public
    view
    returns (int256[])
    {
        return _lockedIdsByIndices;
    }

    function _setLockedIdsByIndices(int256[] ids)
    public
    {
        _lockedIdsByIndices = ids;
    }
}