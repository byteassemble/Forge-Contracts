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

interface IRewardToken is IERC20 {
    function mint(address _to, uint256 _amount) external;
    function decimals() external pure returns (uint8);
    function totalSupply() external view override returns (uint256);
}

contract StakeInitializable is ERC721Holder, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    // Whether a limit is set for users
    bool public hasUserLimit;

    // Accrued token per share
    uint256 public accTokenPerShare;

    // The block number when rewards ends.
    uint256 public endBlock;

    // The block number when rewards starts.
    uint256 public startBlock;

    // The block number of the last pool update
    uint256 public lastRewardBlock;

    // The fee address
    address public feeAddress;

    // The pool limit (0 if none)
    uint256 public poolLimitPerUser;

    // rewards per block.
    uint256 public rewardPerBlock;

    // The precision factor
    uint256 public PRECISION_FACTOR;

    // The reward token
    IRewardToken public rewardToken;

    // The staked nft's collection address
    IERC721 public stakedToken;

    // Total supply of staked token
    uint256 public stakedSupply;

    // Info of each user that stakes tokens (stakedToken)
    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 pending; // reward tokens not sent yet
        uint256 rewardDebt; // Reward debt
        uint256[] tokenIds;  // Staked token ids of user
    }
    mapping(uint256 => address) public tokenOwner;
    mapping(address => UserInfo) public userInfo;

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event Staked(address indexed user, address indexed collection, uint256 tokenId);
    event Unstaked(address indexed user, address indexed collection, uint256 tokenId);
    event RewardPaid(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user);
    event EmergencyRewardWithdraw(uint256 amount);
    event RewardsStop(uint256 blockNumber);

    event NewStartAndEndBlocks(uint256 startBlock, uint256 endBlock);
    event NewRewardPerBlock(uint256 rewardPerBlock);
    event NewFeeAddress(address feeAddress);

    constructor() {}

    /**
     * @notice Initialize the contract
     * @param _stakedToken: staked token address
     * @param _rewardToken: reward token address
     * @param _rewardPerBlock: reward per block (in rewardToken)
     * @param _startBlock: start block
     * @param _endBlock: end block
     * @param _poolLimitPerUser: pool limit per user in stakedToken (if any, else 0)
     * @param _feeAddress: fee address
     * @param _admin: admin address with ownership
     */
    function initialize(
        IERC721 _stakedToken,
        address _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _poolLimitPerUser,
        address _feeAddress,
        address _admin
    ) external {
        require(_startBlock > block.number, "startBlock cannot be in the past");
        require(_startBlock < _endBlock, "startBlock must be lower than endBlock");

        stakedToken = _stakedToken;
        rewardToken = IRewardToken(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _endBlock;
        feeAddress = _feeAddress;

        if (_poolLimitPerUser > 0) {
            hasUserLimit = true;
            poolLimitPerUser = _poolLimitPerUser;
        }

        uint256 decimalsRewardToken = uint256(rewardToken.decimals());
        require(decimalsRewardToken < 20, "Must be inferior to 30");

        PRECISION_FACTOR = uint256(10**(uint256(20).sub(decimalsRewardToken)));

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        // Transfer ownership to the admin address who becomes owner of the contract
        transferOwnership(_admin);
    }

    /*
     * @notice Deposit staked tokens and collect reward tokens (if any)
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function deposit(uint256[] memory tokenIds) external nonReentrant {
        uint256 _length = tokenIds.length;
        require(_length > 0, "Staking: No tokenIds provided");
        
        UserInfo storage user = userInfo[msg.sender];
        if (hasUserLimit) {
            require(
                _length.add(user.amount) <= poolLimitPerUser,
                "User amount above limit"
            );
        }

        _updatePool();
        _updateReward(msg.sender);

        uint256 _amount;
        for (uint256 i = 0; i < _length; i += 1) {
            require(stakedToken.ownerOf(tokenIds[i]) == msg.sender, "User must be the owner of the token");
            user.tokenIds.push(tokenIds[i]);
            // Transfer user's NFTs to the staking contract
            stakedToken.approve(address(this), tokenIds[i]);
            stakedToken.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
            // Increment the amount which will be staked
            _amount += 1;
            emit Staked(msg.sender, address(stakedToken), tokenIds[i]);
        }
        user.amount = user.amount.add(_amount);
        stakedSupply = stakedSupply.add(_amount);

        user.rewardDebt = user.amount.mul(accTokenPerShare).div(PRECISION_FACTOR);
    }

    /*
     * @notice Withdraw staked tokens and collect reward tokens
     * @param _amount: amount to withdraw (in rewardToken)
     */
    function withdraw() external nonReentrant {
        _updatePool();
        _updateReward(msg.sender);

        UserInfo storage user = userInfo[msg.sender];
        require(user.tokenIds.length > 0, "You don't have any staked NFTs!");
        stakedSupply = stakedSupply.sub(user.amount);
        uint256[] memory tokenIds = user.tokenIds;
        user.amount = 0;
        delete user.tokenIds;
        for (uint256 i = 0; i < tokenIds.length; i += 1) {
            // Transfer user's NFTs to the staking contract
            delete tokenOwner[tokenIds[i]];
            stakedToken.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
            // Increment the amount which will be staked
            emit Unstaked(msg.sender, address(stakedToken), tokenIds[i]);
        }
    }

    /**
     * @notice Withdraw staked tokens without caring about rewards rewards
     * @dev Needs to be for emergency.
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amountToTransfer = user.amount;
        uint256[] memory tokenIds = user.tokenIds;
        user.amount = 0;
        user.pending = 0;
        user.rewardDebt = 0;
        stakedSupply = stakedSupply.sub(amountToTransfer);

        if (amountToTransfer > 0) {
            for (uint256 i = 0; i < tokenIds.length; i += 1) {
                // Transfer user's NFTs to the staking contract
                delete tokenOwner[tokenIds[i]];
                stakedToken.safeTransferFrom(address(this), msg.sender, tokenIds[i]);
                // Increment the amount which will be staked
                emit Unstaked(msg.sender, address(stakedToken), tokenIds[i]);
            }
        }
        emit EmergencyWithdraw(msg.sender);
    }

    /**
     * @notice Withdraw all reward tokens
     * @dev Only callable by owner. Needs to be for emergency.
     */
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        require(
            startBlock > block.number || endBlock < block.number,
            "Not allowed to remove reward tokens while pool is live"
        );
        require(rewardToken.balanceOf(address(this)) >= _amount, "Balance is not enough.");
        rewardToken.transfer(msg.sender, _amount);

        emit EmergencyRewardWithdraw(_amount);
    }
    
    /**
     * @notice Claim reward, just in case if rounding error causes pool to not have enough reward tokens.
     */
    function claimReward() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.pending > 0, "0 rewards yet");
        uint256 rewardAmount = user.pending;
        user.pending = 0;
        rewardToken.mint(msg.sender, rewardAmount);

        emit RewardPaid(msg.sender, rewardAmount);
    }

    /*
     * @notice Stop rewards
     * @dev Only callable by owner
     */
    function stopReward() external onlyOwner {
        require(startBlock < block.number, "Pool has not started");
        require(block.number <= endBlock, "Pool has ended");
        endBlock = block.number;

        emit RewardsStop(block.number);
    }

    /*
     * @notice Update reward per block
     * @dev Only callable by owner.
     * @param _rewardPerBlock: the reward per block
     */
    function updateRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        _updatePool();
        rewardPerBlock = _rewardPerBlock;
        emit NewRewardPerBlock(_rewardPerBlock);
    }

    /*
     * @notice Update fee address
     * @dev Only callable by owner.
     * @param _feeAddress: the fee address
     */
    function updateFeeAddress(address _feeAddress) external onlyOwner {
        require(_feeAddress != address(0), "Invalid zero address");
        require(feeAddress != _feeAddress, "Same fee address already set");

        feeAddress = _feeAddress;
        emit NewFeeAddress(feeAddress);
    }

    /**
     * @notice It allows the admin to update start and end blocks
     * @dev This function is only callable by owner.
     * @param _startBlock: the new start block
     * @param _endBlock: the new end block
     */
    function updateStartAndEndBlocks(
        uint256 _startBlock,
        uint256 _endBlock
    ) external onlyOwner {
        require(block.number < startBlock, "Pool has started");
        require(_startBlock < _endBlock, "New startBlock must be lower than new endBlock");
        require(block.number < _startBlock, "New startBlock must be higher than current block");

        startBlock = _startBlock;
        endBlock = _endBlock;

        // Set the lastRewardBlock as the startBlock
        lastRewardBlock = startBlock;

        emit NewStartAndEndBlocks(_startBlock, _endBlock);
    }

    /**
     * @notice It allows the admin to recover wrong tokens sent to the contract
     * @param _tokenAddress: the address of the token to withdraw
     * @param _tokenAmount: the number of tokens to withdraw or tokenid when it's ERC721
     * @dev This function is only callable by admin.
     */
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount, bool _type) external onlyOwner {
        require(_tokenAddress != address(stakedToken), "Cannot be staked token");
        require(_tokenAddress != address(rewardToken), "Cannot be reward token");
        if (_type) {
            IERC721(_tokenAddress).safeTransferFrom(address(this), msg.sender, _tokenAmount);
        } else {
            ERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);
        }

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /*
     * @notice View function to see pending reward on frontend.
     * @param _user: user address
     * @return Pending reward for a given user
     */
    function _updateReward(address _user) internal {
        UserInfo storage user = userInfo[_user];
        uint256 adjustedTokenPerShare = accTokenPerShare;

        if (block.number > lastRewardBlock && stakedSupply != 0) {
            uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
            uint256 _rewards = multiplier.mul(rewardPerBlock);
            adjustedTokenPerShare = accTokenPerShare.add(
                _rewards.mul(PRECISION_FACTOR).div(stakedSupply)
            );
        }

        uint256 pending = user.amount.mul(adjustedTokenPerShare).div(PRECISION_FACTOR).sub(user.rewardDebt);
        user.pending = user.pending.add(pending);
    }

    /*
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }

        if (stakedSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = _getMultiplier(lastRewardBlock, block.number);
        uint256 _rewards = multiplier.mul(rewardPerBlock);
        accTokenPerShare = accTokenPerShare.add(
            _rewards.mul(PRECISION_FACTOR).div(stakedSupply)
        );
        lastRewardBlock = block.number;
    }

    /*
     * @notice Return reward multiplier over the given _from to _to block.
     * @param _from: block to start
     * @param _to: block to finish
     */
    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if (_to <= endBlock) {
            return _to.sub(_from);
        } else if (_from >= endBlock) {
            return 0;
        } else {
            return endBlock.sub(_from);
        }
    }
}
