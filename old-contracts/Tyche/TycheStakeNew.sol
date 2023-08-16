// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract TycheStake is ERC721Holder, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    
    struct PoolInfo {
        uint256 id;  // index of pool
        address rewardToken1;
        address rewardToken2;  // If provide the second reward token. If not, 0x
        uint256 startTime;
        uint256 endTime;
        uint256 rewardPerSecond1;  // reward amount per second for reward token1
        uint256 rewardPerSecond2;  // reward amount per second for reward token2
        uint256 lastRewardTime;
        uint256 stakedSupply;
        uint256 accPerShare1;
        uint256 accPerShare2;
    }
    uint256 public totalCollections = 0;
    mapping(address => bool) public whitelist;
    // stakeToken address => PoolInfo
    mapping(address => PoolInfo) public pools;
    mapping(uint256 => address) public poolIndex;

    struct UserInfo {
        uint256 amount;  // How many tokens staked per collection
        uint256 pending1;  // reward tokens not sent yet for first reward token
        uint256 debt1;  // Reward debt for first reward token
        uint256 pending2;  // reward tokens not sent yet for second token
        uint256 debt2;  // Reward debt for second reward token
        uint256[] tokenIds;  // staked token ids
    }
    // user => collection => UserInfo
    mapping(address => mapping(address => UserInfo)) public users;
    // user => collections // view
    mapping(address => address[]) public userCollections;
    // check user staked for add/remove, user => collection => bool
    mapping(address => mapping(address => bool)) public isUserCollection;
    // collection => tokenId => user address
    mapping(address => mapping(uint256 => address)) public tokenOwners;
    
    event CreatePool(
        address stakeToken,
        address rewardToken1,
        uint256 rewardPerSecond1,
        uint256 startTime,
        uint256 endTime,
        address rewardToken2,
        uint256 rewardPerSecond2
    );
    event Stake(address user, address collection, uint256 tokenId);
    event Unstake(address user, address collection, uint256 tokenId);
    event Claim(address user, address collection, address rewardToken, uint256 amount);
    event UpdateReward(address collection, uint256 rate1, uint256 rate2);
    event UpdateStartTime(address collection, uint256 startTime);
    event UpdateEndTime(address collection, uint256 endTime);

    constructor() {}
    
    function createPool(
        address _stakeToken,
        address _rewardToken1,
        uint256 _rewardPerSecond1,
        uint256 _startTime,
        uint256 _endTime,
        address _rewardToken2,
        uint256 _rewardPerSecond2
    ) external onlyOwner {
        require(!whitelist[_stakeToken], "The collection is added already.");
        totalCollections = totalCollections.add(1);
        PoolInfo memory pool = pools[_stakeToken];
        pool.id = totalCollections;
        pool.startTime = _startTime;
        pool.endTime = _endTime;
        pool.lastRewardTime = _startTime;
        pool.stakedSupply = 0;
        pool.rewardToken1 = _rewardToken1;
        pool.rewardPerSecond1 = _rewardPerSecond1;
        if (_rewardToken2 == address(0)) {
            pool.rewardToken2 = address(0);
            pool.rewardPerSecond2 = 0;
        } else {
            pool.rewardToken2 = _rewardToken2;
            pool.rewardPerSecond2 = _rewardPerSecond2;
        }
        pool.accPerShare1 = 0;
        pool.accPerShare2 = 0;

        pools[_stakeToken] = pool;
        whitelist[_stakeToken] = true;
        poolIndex[totalCollections] = _stakeToken;
        emit CreatePool(_stakeToken, _rewardToken1, _rewardPerSecond1, _startTime, _endTime, _rewardToken2, _rewardPerSecond2);
    }

    function stakeOne(address _stakeToken, uint256 _tokenId) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        require(IERC721(_stakeToken).ownerOf(_tokenId) == msg.sender, "User must be the owner of the token");
        _updatePool(_stakeToken);
        _updateReward(_stakeToken, msg.sender);

        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];
        // Transfer user's NFTs to the staking contract
        IERC721(_stakeToken).approve(address(this), _tokenId);
        IERC721(_stakeToken).safeTransferFrom(msg.sender, address(this), _tokenId);
        // Update data
        user.tokenIds.push(_tokenId);
        user.amount = user.amount.add(1);
        pool.stakedSupply = pool.stakedSupply.add(1);
        tokenOwners[_stakeToken][_tokenId] = msg.sender;
        if (!isUserCollection[msg.sender][_stakeToken]) {
            isUserCollection[msg.sender][_stakeToken] = true;
            userCollections[msg.sender].push(_stakeToken);
        }

        emit Stake(msg.sender, _stakeToken, _tokenId);
        user.debt1 = user.amount.mul(pool.accPerShare1);
        user.debt2 = user.amount.mul(pool.accPerShare2);
    }

    function stake(address _stakeToken, uint256[] memory _tokenIds) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        uint256 _length = _tokenIds.length;
        require(_length > 0, "Staking: No tokenIds provided");
        _updatePool(_stakeToken);
        _updateReward(_stakeToken, msg.sender);

        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];
        uint256 _amount;
        for (uint256 i =0; i < _length; i++) {
            require(IERC721(_stakeToken).ownerOf(_tokenIds[i]) == msg.sender, "User must be the owner of the token");
            // Transfer user's NFTs to the staking contract
            IERC721(_stakeToken).approve(address(this), _tokenIds[i]);
            IERC721(_stakeToken).safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
            // Update data
            user.tokenIds.push(_tokenIds[i]);
            _amount += 1;
            tokenOwners[_stakeToken][_tokenIds[i]] = msg.sender;
            emit Stake(msg.sender, _stakeToken, _tokenIds[i]);
        }
        user.amount = user.amount.add(_amount);
        pool.stakedSupply = pool.stakedSupply.add(_amount);
        if (!isUserCollection[msg.sender][_stakeToken]) {
            isUserCollection[msg.sender][_stakeToken] = true;
            userCollections[msg.sender].push(_stakeToken);
        }

        user.debt1 = user.amount.mul(pool.accPerShare1);
        user.debt2 = user.amount.mul(pool.accPerShare2);
    }

    function unstakeOne(address _stakeToken, uint256 _tokenId) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        require(tokenOwners[_stakeToken][_tokenId] == msg.sender, "Token owner can unstake only");
        _updatePool(_stakeToken);
        _updateReward(_stakeToken, msg.sender);

        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];
        for(uint256 i = 0; i < user.tokenIds.length - 1; i++) {
            if (user.tokenIds[i] == _tokenId) {
                user.tokenIds[i] = user.tokenIds[user.tokenIds.length - 1];
            }
        }
        user.tokenIds.pop();
        user.amount = user.amount.sub(1);
        pool.stakedSupply = pool.stakedSupply.sub(1);
        IERC721(_stakeToken).safeTransferFrom(address(this), msg.sender, _tokenId);
        tokenOwners[_stakeToken][_tokenId] = address(0);
        if (user.amount == 0) {
            // send reward
            _claim(_stakeToken, msg.sender);
            // remove user collection
            isUserCollection[msg.sender][_stakeToken] = false;
            for(uint256 i = 0; i < userCollections[msg.sender].length - 1; i++) {
                if (userCollections[msg.sender][i] == _stakeToken) {
                    userCollections[msg.sender][i] = userCollections[msg.sender][user.tokenIds.length - 1];
                }
            }
            userCollections[msg.sender].pop();
        }

        emit Unstake(msg.sender, _stakeToken, _tokenId);
        user.debt1 = user.amount.mul(pool.accPerShare1);
        user.debt2 = user.amount.mul(pool.accPerShare2);
    }

    function unstake(address _stakeToken) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        _updatePool(_stakeToken);
        _updateReward(_stakeToken, msg.sender);

        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];
        pool.stakedSupply = pool.stakedSupply.sub(user.amount);
        uint256[] memory tokenIds = user.tokenIds;
        user.amount = 0;
        delete user.tokenIds;
        for (uint256 i = 0; i < tokenIds.length; i += 1) {
            IERC721(_stakeToken).safeTransferFrom(address(this), msg.sender, tokenIds[i]);
            tokenOwners[_stakeToken][tokenIds[i]] = address(0);
            emit Unstake(msg.sender, _stakeToken, tokenIds[i]);
        }
        // send reward
        _claim(_stakeToken, msg.sender);
        // remove user collection
        isUserCollection[msg.sender][_stakeToken] = false;
        for(uint256 i = 0; i < userCollections[msg.sender].length - 1; i++) {
            if (userCollections[msg.sender][i] == _stakeToken) {
                userCollections[msg.sender][i] = userCollections[msg.sender][user.tokenIds.length - 1];
            }
        }
        userCollections[msg.sender].pop();

        user.debt1 = 0;
        user.debt2 = 0;
    }

    function claim(address _stakeToken) external nonReentrant {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        _updatePool(_stakeToken);
        _updateReward(_stakeToken, msg.sender);

        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[msg.sender][_stakeToken];
        _claim(_stakeToken, msg.sender);
        user.debt1 = user.amount.mul(pool.accPerShare1);
        user.debt2 = user.amount.mul(pool.accPerShare2);
    }

    function _claim(address _stakeToken, address _userAddress) internal {
        PoolInfo storage _pool = pools[_stakeToken];
        UserInfo storage _user = users[_userAddress][_stakeToken];
        uint256 rewardAmount1 = _user.pending1;
        uint256 rewardAmount2 = _user.pending2;
        _user.pending1 = 0;
        _user.pending2 = 0;
        require(IERC20(_pool.rewardToken1).balanceOf(address(this)) >= rewardAmount1, "Balance1 is not enough");
        IERC20(_pool.rewardToken1).transfer(msg.sender, rewardAmount1);
        emit Claim(msg.sender, _stakeToken, _pool.rewardToken1, rewardAmount1);
        if (_pool.rewardToken2 != address(0)) {
            require(IERC20(_pool.rewardToken2).balanceOf(address(this)) >= rewardAmount2, "Balance2 is not enough");
            IERC20(_pool.rewardToken2).transfer(msg.sender, rewardAmount2);
            emit Claim(msg.sender, _stakeToken, _pool.rewardToken2, rewardAmount2);
        }
    }

    // Internal functions
    function _updateReward(address _stakeToken, address _user) internal {
        PoolInfo storage pool = pools[_stakeToken];
        UserInfo storage user = users[_user][_stakeToken];
        uint256 adjustedPerShare1 = pool.accPerShare1;
        uint256 adjustedPerShare2 = pool.accPerShare2;
        uint256 multiplier = _getMultiplier(pool.lastRewardTime, block.timestamp, pool.endTime);

        if (block.timestamp > pool.lastRewardTime && pool.stakedSupply != 0) {
            uint256 _rewards1 = multiplier.mul(pool.rewardPerSecond1);
            adjustedPerShare1 = pool.accPerShare1.add(_rewards1.div(pool.stakedSupply));
        }
        uint256 pending1 = user.amount.mul(adjustedPerShare1).sub(user.debt1);
        user.pending1 = user.pending1.add(pending1);

        if (pool.rewardToken2 != address(0)) {
            if (block.timestamp > pool.lastRewardTime && pool.stakedSupply != 0) {
                uint256 _rewards2 = multiplier.mul(pool.rewardPerSecond2);
                adjustedPerShare2 = pool.accPerShare2.add(_rewards2.div(pool.stakedSupply));
            }
            uint256 pending2 = user.amount.mul(adjustedPerShare2).sub(user.debt2);
            user.pending2 = user.pending2.add(pending2);
        }
    }

    function _updatePool(address _stakeToken) internal {
        PoolInfo storage pool = pools[_stakeToken];
        if (block.timestamp <= pool.lastRewardTime) { return; }
        if (pool.stakedSupply == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = _getMultiplier(pool.lastRewardTime, block.timestamp, pool.endTime);
        uint256 _rewards1 = multiplier.mul(pool.rewardPerSecond1);
        pool.accPerShare1 = pool.accPerShare1.add(_rewards1.div(pool.stakedSupply));
        if (pool.rewardToken2 != address(0)) {
            uint256 _rewards2 = multiplier.mul(pool.rewardPerSecond2);
            pool.accPerShare2 = pool.accPerShare2.add(_rewards2.div(pool.stakedSupply));
        }
        pool.lastRewardTime = block.timestamp;
    }

    function _getMultiplier(uint256 _from, uint256 _to, uint256 _endTime) internal pure returns (uint256) {
        if (_to <= _endTime) {
            return _to.sub(_from);
        } else if (_from >= _endTime) {
            return 0;
        } else {
            return _endTime.sub(_from);
        }
    }

    function recoverWrongTokens(address _rewardToken) external onlyOwner {
        IERC20(_rewardToken).transfer(msg.sender, IERC20(_rewardToken).balanceOf(address(this)));
    }

    function updateRewardRate(address _stakeToken, uint256 _newRate1, uint256 _newRate2) external onlyOwner {
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        _updatePool(_stakeToken);
        PoolInfo storage pool = pools[_stakeToken];
        pool.rewardPerSecond1 = _newRate1;
        pool.rewardPerSecond2 = _newRate2;
        emit UpdateReward(_stakeToken, _newRate1, _newRate2);
    }

    function updateStartTime(address _stakeToken, uint256 _startTime) external onlyOwner {
        require(block.timestamp < _startTime, "New startBlock must be higher than current block");
        require(whitelist[_stakeToken], "The token is not allowed to stake!");
        PoolInfo storage pool = pools[_stakeToken];
        require(block.timestamp < pool.startTime, "Pool has started already");

        pool.startTime = _startTime;
        pool.lastRewardTime = _startTime;

        emit UpdateStartTime(_stakeToken, _startTime);
    }

    function getUserTokenIds(address _user, address _stakeToken) public view returns(uint256[] memory) {
        return users[_user][_stakeToken].tokenIds;
    }

    function getUserCollections(address _user) public view returns(address[] memory) {
        return userCollections[_user];
    }
}
