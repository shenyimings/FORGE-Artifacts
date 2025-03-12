/**
 *Submitted for verification at Etherscan.io on 2021-04-13
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./extensions/IERC20.sol";
import "./extensions/ILocker.sol";


struct LockRecord {
    uint256 start;
    uint256 end;
    // amount of token being locked
    uint256 lockAmount;
    uint256 rewardPerBlock;
    // unlock 5% after IDO or not
    bool unlockAfterIDO;
}

contract LockerV2 is Ownable, ILocker {
    // contains addresses that were in the seeding, private sale or marketing campaign
    // these addresses will be locked from sending their token to other addresses in different durations
    // these lock durations will be stored in lockRecords
    mapping(address => bool) public whitelist;
    //mapping from address to presale stage -> lock amount
    mapping(address => LockRecord) public lockRecords;

    uint public IDOUnlockPercent;

    uint public IDOStartBlock;

    uint public October1st = 11362690;
    uint public Octorber2022 = October1st + 28800*365;
    uint public October2025 = October1st + (28800*365*4);
    uint public January1st = 14020845;
    uint public April1st = January1st + 28800*(365 + 90);

    IERC20 public fiwa;

    event Lock(address addr, uint start, uint end, uint amount, bool unlockAfterIDO);

    constructor(address _fiwa) {
        IDOUnlockPercent = 500;
        fiwa = IERC20(_fiwa);
        //unlock 5% after this block (10pm 07-09-2021)
        IDOStartBlock = 10710000;
        lockInvestorGroupOne();
        lockInvestorGroupTwo();
        lockInvestorGroupThree();
        lockInvestorGroupFour();
        lockDevelopers();
    }

    function setIDOUnlockPercent(uint _percent) external onlyOwner {
        require(0 <= _percent && _percent <= 10000, "Percent must > 0 and <= 10000");
        IDOUnlockPercent = _percent;
    }

    function setIDOBlock(uint _block) external onlyOwner {
        IDOStartBlock = _block;
    }

    function lockInvestorGroupOne() internal {
        lock(0x86Ca3b84B77F65913baA9d324dBF838a2FD9db66, 50000000* 10**18, October1st, Octorber2022, true);
        lock(0xB9a85Cf9C0b71Ab3245cb7BCF2da572AE1DC58Bf, 105000000* 10**18, October1st, Octorber2022, true);
        lock(0x6d16749cEfb3892A101631279A8fe7369A281D0E, 36666667* 10**18, October1st, Octorber2022, true);
        lock(0x918A97AD195DD111C54Ea82E2F8B8D22E9f48726, 73333333* 10**18, October1st, Octorber2022, true);
        lock(0x42560B34EA6Beb5A1Bf327D306f70D6ff02D53C6, 35000000* 10**18, October1st, Octorber2022, true);
        lock(0xFcbf806792f06d9c78E50B3737E1a22cfC36a942, 20000000* 10**18, October1st, Octorber2022, true);
        lock(0xBc934494675a6ceB639B9EfEe5b9C0f017D35a75, 22000000* 10**18, October1st, Octorber2022, true);
        lock(0xbE8FF5C9d74aFd3F08886256f0B1E9BA18Bf83b9, 147400000* 10**18, October1st, Octorber2022, true);
        lock(0x053a00953095876496e89C06898f0E441B49266E, 72600000* 10**18, October1st, Octorber2022, true);
        lock(0x4F76e9779F4eF8Ea8361CecDEe0a2ccdbA4B06ba, 35000000* 10**18, October1st, Octorber2022, true);
        lock(0x6B612345b032217E9A77f4Be24393dbECDd8E5Fe, 110000000* 10**18, October1st, Octorber2022, true);
        lock(0xDCD50C64C5F416Ff6842C9C49146597D8f05A027, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0x3c8972bA9D1Ba82acf390ab6e7fCC29dD3a7c53E, 35000000* 10**18, October1st, Octorber2022, true);
        lock(0x5565d64f29Ea17355106DF3bA5903Eb793B3e139, 70000000* 10**18, October1st, Octorber2022, true);
        lock(0xC7E5cECEaa3E48F84354Cff49EcCCEdE629eB105, 70000000* 10**18, October1st, Octorber2022, true);
        lock(0xa5d06D8417323eECf8c14e83E81205836A07470D, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0xe864A1c32357dF67Cb7C9bEe8EC76C8904366666, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0xfedE84Ed262f3bd2e607cf5b9e6E97be7da273d0, 49000000* 10**18, October1st, Octorber2022, true);
        lock(0x05AeB176197F1800465285907844913a2bc02e75, 35000000* 10**18, October1st, Octorber2022, true);
        lock(0xD5237A08BE8a9133D446F204fDB056F808862450, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0xF5379F1ce2523e2C09158c73236CEB0272eCD211, 2666667* 10**18, October1st, Octorber2022, true);
        lock(0x0c328D17a93EeA9aE5872737AB9C26A370f6A8f4, 2666667* 10**18, October1st, Octorber2022, true);
        lock(0x3385ab2cA1cA817B0de5d842E0F84bF1ffFA379F, 4833333* 10**18, October1st, Octorber2022, true);
    }

    function lockInvestorGroupTwo() internal {
        lock(0xfc7c0Eb749705e0Ec1b6585724B0E9Bde83B80DB, 10370000* 10**18, October1st, Octorber2022, true);
        lock(0x0051437667689B36f9cFec31E4F007f1497c0F98, 35000000* 10**18, October1st, Octorber2022, true);
        lock(0xF14c9dbDb31b0a18aF44Fcf97Ed12b0abfE1b92e, 53333334* 10**18, October1st, Octorber2022, true);
        lock(0x966a6C3A4e973c33EDd0665e22098f6a4d152448, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0x5f8287716B31161267b8F360EF8663EED97b755c, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0x41E3FE77DE1EcA115902eB058b1FB57395358d62, 40000000* 10**18, October1st, Octorber2022, true);
        lock(0x67EE92BEEb618b01777E37e8368A0Fd4fEBdF9A4, 6666667* 10**18, October1st, Octorber2022, true);
        lock(0xC3E53C7Fa9C282f0C81abE97125D8c0676C87d86, 35000000* 10**18, October1st, Octorber2022, true);
        lock(0x529C9428572fFd389b031f7bd5bdC44b3F471D8e, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0xfDB3519f49149ffBd787927cd09792eeacCdd56C, 35000000* 10**18, October1st, Octorber2022, true);
        lock(0x8ABA994DB3583fBb1CDBD7887b4a13e5329cEAD2, 58333333* 10**18, October1st, Octorber2022, true);
        lock(0xC47fFa924a645fB497d30b69C80C55B6Dd9a1105, 2000000* 10**18, October1st, Octorber2022, true);
        lock(0x4a5BB1c9347A0d4F7e06a29239162f03647d9232, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0xa451fD4bd55d103D9F4BF01a716E6Bbb9823A24f, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0xF6Ae888a62166B763faE9d83e5661de8da2ff8eF, 189000000* 10**18, October1st, Octorber2022, true);
        lock(0x04616EA20406B2388583A0cb1154430A34753dF7, 33333333* 10**18, October1st, Octorber2022, true);
        lock(0x11eA9D993cA8A95EC4BD63dA4FA9B8AC82F9e708, 1500000* 10**18, October1st, Octorber2022, true);
        lock(0xe2EEE0a71d470cD7462b6F8e265250Be0a5c2a99, 23333333* 10**18, October1st, Octorber2022, true);
        lock(0x58E78124fe7cc061E1A9c05118379E72f0ed0621, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0x2711AC599bf1AC597841356D0ed3309b51a26015, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0x3b892DC004aB2C67E32728a3f5e045AA3dEd74d4, 1000000* 10**18, October1st, Octorber2022, true);
        lock(0xA16deCb38CF01dbdcFdaB0B9265AEfF1CFE9BD86, 10000000* 10**18, October1st, Octorber2022, true);
        lock(0x4553eD5d8d3731E629f67BD86abd021175F31848, 6666667* 10**18, October1st, Octorber2022, true);
    }

    function lockInvestorGroupThree() internal {
        lock(0x5ba7614B0b5E901A762AF4c03C6a33D85D7B35DD, 6666667* 10**18, October1st, Octorber2022, true);
        lock(0xDa4f84247Bd3aC0705757267Ab2742Aa3bEb84F3, 20000000* 10**18, October1st, Octorber2022, true);
        lock(0xBE551dD71CFcd5e78157840Dc87Bd70b7204A20f, 10000000* 10**18, October1st, Octorber2022, true);
        lock(0x083472030626B27e5f81761Ea7B44A08e32bC7a2, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0x80Fcc1b8c390d054f5e64811977d3d5246FFE162, 26666667* 10**18, October1st, Octorber2022, true);
        lock(0xCA63CD425d0e78fFE05a84c330Bfee691242113d, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0xb14025f7eB7717cFF43e7a33b66d86eaBd6bC7d7, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0x605F3E3e5AdB86DedF3966dAa9cA671199C27f44, 33333333* 10**18, October1st, Octorber2022, true);
        lock(0xD266d61ac22C2a2Ac2Dd832e79c14EA152c998D6, 33333333* 10**18, October1st, Octorber2022, true);
        lock(0x3830119cb52E7A3Ade67f0DCDbF68AE757f0382f, 13333333* 10**18, October1st, Octorber2022, true);
        lock(0x50bEc6F02aa38577955e3D595137B335fcF1a822, 6666667* 10**18, October1st, Octorber2022, true);
        lock(0xe351FD6Ccc94cdD340adcE47a265A39f02661544, 6666667* 10**18, October1st, Octorber2022, true);
        lock(0x6b779ae702A4E139039151b05bEB2730356047DA, 6666667* 10**18, October1st, Octorber2022, true);
        lock(0xe92D80a90bc050A12F1c6fBE0e50e1B5A874B595, 5333333* 10**18, October1st, Octorber2022, true);
        lock(0x40895b2578041a5C284cD3B49B332d3aADF7162E, 16666667* 10**18, October1st, Octorber2022, true);
        lock(0xA16deCb38CF01dbdcFdaB0B9265AEfF1CFE9BD86, 5333334* 10**18, October1st, Octorber2022, true);
        lock(0xd25E1b6bb02823658a4b3c0F6C689046a52E2B23, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0x92B793DF58702511ABAC04b39bd573FdBFb1c8ce, 1333333* 10**18, October1st, Octorber2022, true);
        lock(0x6E2F18679b1AEf7D2390830d88dd1F6dc8d66032, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0xF2385811df9dCd791a9Aaf0586d8082680e6C163, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0xc69A36f448d8a4b8282033ef6A209C2fF3d330C7, 1333333* 10**18, October1st, Octorber2022, true);
        lock(0xcCCBB51d608046431F63817aD9605174614cf7C9, 2000000* 10**18, October1st, Octorber2022, true);
    }

    function lockInvestorGroupFour() internal {
        lock(0x57f55850547BA26Ff524644DA5E5604B0B0D7900, 2000000* 10**18, October1st, Octorber2022, true);
        lock(0x399b282c17F8ed9F542C2376917947d6B79E2Cc6, 1333333* 10**18, October1st, Octorber2022, true);
        lock(0x96F89B37334dBA99b867ab812C1bbDf2E2103D23, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0xdF17c6402312Dfae82bCAFbaE0F3b1A14905202f, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0x7C67c409Fea0b084B31bC38dA950E0A41EA3AEc3, 6666667* 10**18, October1st, Octorber2022, true);
        lock(0x61eeE1D22D3ca1DF312cAFCc084E7D32F707FaE9, 333333* 10**18, October1st, Octorber2022, true);
        lock(0x32AccAEfa35620b51c061901AFf1B74991E7322b, 333333* 10**18, October1st, Octorber2022, true);
        lock(0xf3815489b70C0A3a0B626f183B1f1240F63E06a6, 500000* 10**18, October1st, Octorber2022, true);
        lock(0x2938b2a7EbF9a59645E39d51ec5eCA2869D6C53D, 1000000* 10**18, October1st, Octorber2022, true);
        lock(0xB3977ABC3e8fdf9B6b2B64A591dB5D22AFBCd588, 333333* 10**18, October1st, Octorber2022, true);
        lock(0xB67e49A45858F3CBf2bC2026A4347B5518279798, 333333* 10**18, October1st, Octorber2022, true);
        lock(0x94F9FDb43A2b98B2920BcD37848D2165F2007511, 666667* 10**18, October1st, Octorber2022, true);
        lock(0xd69509aF4199D975A355dA4b45B4597931486Bd3, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0xaC6dE9f16c7b9B44C4e5C9073C3a10fA45aB4d5a, 1333333* 10**18, October1st, Octorber2022, true);
        lock(0x54D07CFa91F05Fe3B45d8810feF05705117AFe53, 1333333* 10**18, October1st, Octorber2022, true);
        lock(0x2feE1fe8b98D06dD116BE23f019869aBEdb0bFbb, 666667* 10**18, October1st, Octorber2022, true);
        lock(0x98bbd040dAA80675046143958F6D169fd681953a, 3333333* 10**18, October1st, Octorber2022, true);
        lock(0xFfbAD33e6d78a7fA76a863d843CF8D9596CBAE1F, 2000000* 10**18, October1st, Octorber2022, true);
        lock(0x26767436CDC89798572a27666C1ca36d6f99c481, 1333333* 10**18, October1st, Octorber2022, true);
        lock(0x50899582199c06d5264edDCD12879E5210783Ba8, 666667* 10**18, October1st, Octorber2022, true);
        lock(0x7DD3796cd92C40Ac9C0F5dA27D06eCefeE7F7715, 16666667* 10**18, October1st, Octorber2022, true);
        lock(0x382f421B79FCB9209Aaa06A11fCDaceB88aBF00E, 33333333* 10**18, October1st, Octorber2022, true);
    }

    function lockDevelopers() internal {
        // ecosystem and liquidity: 48 months
        lock(0x05cCB949F0F8637c4a67ABe314de446deb8D7BAe, 5800000000* 10**18, October1st, October2025, true);
        // devs and founders: 15 months from January1st 2022, no unlock for IDO
        lock(0x07903024F554348799C25e79da5977C32Edd764e, 1500000000* 10**18, January1st, April1st, false);
        // marketing and partnership: 12 months
        lock(0x1339c9aD4c6cA8993535Bcb7e401177e3DaC0fA2, 700000000* 10**18, October1st, Octorber2022, true);
    }

    /**
     * @dev lock an account from transfering CORI token in a specific block number
     * @param addr: account to be locked
     * @param amount: number of token will be locked
     * @param start: block number when the release token start
     * @param end: block number when the release token end
     */
    function lock(address addr, uint256 amount, uint256 start, uint256 end, bool unlockAfterIDO) internal  {
        require(start < end, "Invalid lock time");
        whitelist[addr] = true;
        
        uint256 duration = end - start;
        // duration always > 0 so this divide operator won't throw
        uint256 rewardPerBlock = amount / duration;
        uint256 remainder = 0;
        // safety check
        if (rewardPerBlock * duration <= amount)
            remainder = amount - rewardPerBlock * duration;
            
        LockRecord memory lockRecord = LockRecord({
            start: start,
            end: end,
            lockAmount: amount - remainder,
            rewardPerBlock: rewardPerBlock,
            unlockAfterIDO: unlockAfterIDO
        });
        lockRecords[addr] = lockRecord;

        emit Lock(addr, start, end, amount, unlockAfterIDO);
    }

    /**
     * @dev calculate the true amount being locked of an address
     */
    function getLockedAmount(address addr) public view returns(uint256) {
        LockRecord memory lockRecord = lockRecords[addr];

        // unlock 5% of fund after IDO start
        if (block.number >= IDOStartBlock && lockRecord.unlockAfterIDO)
            lockRecord.lockAmount -= lockRecord.lockAmount * IDOUnlockPercent / 10000;

        // havest time is not started 
        if (block.number <= lockRecord.start)
            return lockRecord.lockAmount;

        if (block.number >= lockRecord.end)
            return 0;

        uint256 unlockedAmount = lockRecord.rewardPerBlock * (block.number - lockRecord.start);
        // need this check because we unlock 5% when IDO start
        if (unlockedAmount <= lockRecord.lockAmount)
            return lockRecord.lockAmount - unlockedAmount;
            
        return 0;
    }

     /**
     * @dev check the validity of {newBalance} of {source} address, {newBalance} must bigger than lockedAmount of {source}
     * @param newBalance: balance of user after perform the transfer
     */
    function checkLock(address source, uint256 newBalance) external view override returns (bool) {
        // address not in whitelist, no look needed
        if (!whitelist[source])
            return false;
            
        uint256 lockAmount = getLockedAmount(source);

        if (lockAmount == 0)
            return false;
            
        if (newBalance < lockAmount)
            return true;

        return false;
    }
}