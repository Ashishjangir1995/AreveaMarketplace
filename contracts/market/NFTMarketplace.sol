// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/INFTMarketplace.sol";
import "./Abstract/ANFTMarketplace.sol";
import "./library/AmountTransfer.sol";
    /***
        @notice NFTMarketplace is INFTMarketplace, ANFTMarketplace  .
        @param owner  The address of the contract owner
        @makerFee - platform fee of the market at initial deployement
     */
contract NFTMarketplace is INFTMarketplace, ANFTMarketplace {
    using SafeMath for uint256;
    /**
        initial constructor takes owner and platform fee as input
     **/
    constructor(address _owner, uint256 _makerFee) {
        owner = _owner;
        makerFee = _makerFee;
    }

    /***
        @notice Get the marketFee.
        @param tokenId  The Owner only can set makerfee
        @return         Requested amount makerfee
     */

    function setMakerFee(uint256 _makerFee) external onlyOwner {
        makerFee = _makerFee;
    }
     /***
        @notice Owner can change the contract ownership.
        @param tokenId  The Owner only can make changes 
        @return         Update ownership of the contrct 
     */

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit UpdateOwner(msg.sender, _owner);
    }

    // NFT FIXED SALE

       /***
        @notice Function to buyFromFixedSale
        @param buyFromFixedSale once nft is in fixed sale using this function to buy form market
     */

    function buyFromFixedSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _amount
    )
        external
        payable
        isNftInFixedSale(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_amount)
        buyPriceMeetSalePrice(_nftContractAddress, _tokenId, _amount)
    {
        IERC721(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 0;
        delete fixedSaleNFT[(indexFixedSaleNFT[_nftContractAddress][_tokenId])];

        nftContractFixedSale[_nftContractAddress][_tokenId].nftBuyer = msg
            .sender;

        _isTokenOrCoin(
            nftContractFixedSale[_nftContractAddress][_tokenId].royaltyReciever,
            nftContractFixedSale[_nftContractAddress][_tokenId].nftSeller,
            nftContractFixedSale[_nftContractAddress][_tokenId].erc20,
            nftContractFixedSale[_nftContractAddress][_tokenId].salePrice,
            nftContractFixedSale[_nftContractAddress][_tokenId].royalty,
            false
        );

        emit NftBuyFromFixedSale(
            _nftContractAddress,
            msg.sender,
            _tokenId,
            _amount
        );
    }

     /*
        @notice Function to cancelFixedsale
        @param cancelFixedsale once nft is in fixed sale using this function to cancel sell
     */

    function cancelFixedsale(address _nftContractAddress, uint256 _tokenId)
        external
        isNftInFixedSale(_nftContractAddress, _tokenId)
        isSaleResetByOwner(_nftContractAddress, _tokenId)
    {
        IERC721(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 0;

        delete fixedSaleNFT[(indexFixedSaleNFT[_nftContractAddress][_tokenId])];

        emit CancelNftFixedSale(_nftContractAddress, msg.sender, _tokenId);
    }
    /*
        @notice Function to nftFixedSale
        @param nftFixedSale this function to create nft fixedsale by putting nft details
     */

    function nftFixedSale(
        address _nftContractAddress,
        address _erc20,
        address _royaltyReciever,
        uint256 _royalty,
        uint256 _tokenId,
        uint256 _salePrice
    )
        external
        isSaleStartByOwner(_nftContractAddress, _tokenId)
        isNftAlreadyInSale(_nftContractAddress, _tokenId)
        isContractApprove(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_salePrice)
    {
        nftContractFixedSale[_nftContractAddress][_tokenId] = FixedSale(
            msg.sender,
            address(0),
            _erc20,
            _royaltyReciever,
            _salePrice,
            _royalty
        );

        nftSaleStatus[_nftContractAddress][_tokenId] = 1;

        indexFixedSaleNFT[_nftContractAddress][_tokenId] = fixedSaleNFT.length;
        fixedSaleNFT.push(SaleInfo(_nftContractAddress, _tokenId));

        IERC721(_nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit NftFixedSale(
            _nftContractAddress,
            msg.sender,
            _erc20,
            _tokenId,
            _salePrice,
            block.timestamp
        );
    }
    /*
        @notice Function to updateFixedSalePrice
        @param updateFixedSalePrice this function to updatesale price of nft 
     */
    function updateFixedSalePrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _updateSalePrice
    )
        external
        isNftInFixedSale(_nftContractAddress, _tokenId)
        isSaleResetByOwner(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_updateSalePrice)
    {
        nftContractFixedSale[_nftContractAddress][_tokenId]
            .salePrice = _updateSalePrice;

        emit NftFixedSalePriceUpdated(
            _nftContractAddress,
            _tokenId,
            _updateSalePrice
        );
    }

    // NFT AUCTION SALE
    /*
        @notice Function to createNftAuctionSale
        @param createNftAuctionSale this function to create Auction sale  
     */
    function createNftAuctionSale(
        address _nftContractAddress,
        address _erc20,
        address _royaltyReciever,
        uint256 _royalty,
        uint256 _tokenId,
        uint256 _auctionStart,
        uint256 _auctionEnd,
        uint256 _minPrice
    )
        external
        isSaleStartByOwner(_nftContractAddress, _tokenId)
        isNftAlreadyInSale(_nftContractAddress, _tokenId)
        isContractApprove(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_minPrice)
    {
        _storedNftAuctionDetails(
            _nftContractAddress,
            _erc20,
            _royaltyReciever,
            _royalty,
            _tokenId,
            _auctionStart,
            _auctionEnd,
            _minPrice
        );
    }
     /*
        @notice Function to _cancelAuctionSale
        @param _cancelAuctionSale this function to cancel auction sale during auction  
     */
 
    function _cancelAuctionSale(address _nftContractAddress, uint256 _tokenId)
        external
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionResetByOwner(_nftContractAddress, _tokenId)
        isAuctionOngoing(_nftContractAddress, _tokenId)
        isbidNotMakeTillNow(_nftContractAddress, _tokenId)
    {
        nftSaleStatus[_nftContractAddress][_tokenId] = 0;

        IERC721(_nftContractAddress).safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );

        delete auctionSaleNFT[
            (indexAuctionSaleNFT[_nftContractAddress][_tokenId])
        ];

        emit CancelNftAuctionSale(_nftContractAddress, _tokenId, msg.sender);
    }

     /*
        @notice Function to makeBid
        @param makeBid this function to make bid during auction 
     */

    function makeBid(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _bidPrice
    )
        external
        payable
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionOngoing(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_bidPrice)
        islatestBidGreaterPreviousOne(
            _nftContractAddress,
            _tokenId,
            msg.value,
            _bidPrice
        )
    {
        if (
            nftContractAuctionSale[_nftContractAddress][_tokenId].erc20 !=
            address(0)
        ) {
            AmountTransfer.bidAmountTransfer(
                _bidPrice,
                nftContractAuctionSale[_nftContractAddress][_tokenId].erc20,
                msg.sender
            );
        }

        nftContractAuctionSale[_nftContractAddress][_tokenId]
            .nftHighestBid = _bidPrice;
        nftContractAuctionSale[_nftContractAddress][_tokenId]
            .nftHighestBidder = msg.sender;

        userBidPriceOnNFT[_nftContractAddress][_tokenId][
            msg.sender
        ] = _bidPrice;

        emit NftBidPrice(_nftContractAddress, _tokenId, _bidPrice, msg.sender);
    }

    function settleAuction(address _nftContractAddress, uint256 _tokenId)
        external
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionOver(_nftContractAddress, _tokenId)
    {
        address nftBuyer = nftContractAuctionSale[_nftContractAddress][_tokenId]
            .nftHighestBidder;

        _transferNftAndPaySeller(
            _nftContractAddress,
            _tokenId,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftHighestBid,
            nftBuyer
        );

        userBidPriceOnNFT[_nftContractAddress][_tokenId][nftBuyer] = 0;
        delete auctionSaleNFT[
            (indexAuctionSaleNFT[_nftContractAddress][_tokenId])
        ];

        emit NftAuctionSettle(
            _nftContractAddress,
            _tokenId,
            nftBuyer,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftHighestBid,
            nftContractAuctionSale[_nftContractAddress][_tokenId].nftSeller
        );
    }
     /*
        @notice Function to updateTheBidPrice
        @param updateTheBidPrice this function to updateTheBidPrice during auction 
     */
    function updateTheBidPrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _updateBidPrice
    )
        external
        payable
        isNftInAuctionSale(_nftContractAddress, _tokenId)
        isAuctionOngoing(_nftContractAddress, _tokenId)
        priceGreaterThanZero(_updateBidPrice)
        isUpdatedBidGreaterPreviousOne(
            _nftContractAddress,
            _tokenId,
            msg.value,
            _updateBidPrice
        )
    {
        address nftContractAddress = _nftContractAddress;
        uint256 tokenId = _tokenId;
        uint256 finalBidPrice = userBidPriceOnNFT[nftContractAddress][tokenId][
            msg.sender
        ].add(_updateBidPrice);

        if (
            nftContractAuctionSale[nftContractAddress][tokenId].erc20 !=
            address(0)
        ) {
            AmountTransfer.bidAmountTransfer(
                _updateBidPrice,
                nftContractAuctionSale[nftContractAddress][tokenId].erc20,
                msg.sender
            );
        }

        nftContractAuctionSale[nftContractAddress][tokenId]
            .nftHighestBid = finalBidPrice;
        nftContractAuctionSale[nftContractAddress][tokenId]
            .nftHighestBidder = msg.sender;

        userBidPriceOnNFT[nftContractAddress][tokenId][
            msg.sender
        ] = finalBidPrice;

        emit NftAuctionBidPriceUpdate(
            nftContractAddress,
            tokenId,
            finalBidPrice,
            msg.sender
        );
    } 
     /*
        @notice Function to withdrawBid
        @param updateTheBidPrice this function to withdrawBid 
     */

    function withdrawBid(address _nftContractAddress, uint256 _tokenId)
        external
    {
        require(
            msg.sender !=
                nftContractAuctionSale[_nftContractAddress][_tokenId]
                    .nftHighestBidder,
            "You are highest bidder"
        );
        require(
            userBidPriceOnNFT[_nftContractAddress][_tokenId][msg.sender] > 0,
            "nothing to withdraw"
        );

        uint256 amount = userBidPriceOnNFT[_nftContractAddress][_tokenId][
            msg.sender
        ];
        address _erc20 = nftContractAuctionSale[_nftContractAddress][_tokenId]
            .erc20;

        if (_erc20 != address(0)) {
            IERC20(_erc20).transfer(msg.sender, amount);
        } else {
            AmountTransfer.nativeAmountTransfer(msg.sender, amount);
        }

        userBidPriceOnNFT[_nftContractAddress][_tokenId][msg.sender] = 0;

        emit withdrawNftBid(_nftContractAddress, _tokenId, msg.sender);
    }

    //view function
    /*
        @notice its a view function to getAuctionSaleNFT
        @param updateTheBidPrice this function to view nft details 
     */

    function getAuctionSaleNFT() external view returns (SaleInfo[] memory) {
        return auctionSaleNFT;
    }
      /*
        @notice its a view function to getFixedSale
        @param getFixedSale this function to view nft fixedsale details 
     */
    function getFixedSale(address _nftContractAddress, uint256 _tokenId)
        external
        view
        returns (FixedSale memory)
    {
        return nftContractFixedSale[_nftContractAddress][_tokenId];
    }
     /*
        @notice its a view function to getFixedSaleNFT
        @param getFixedSaleNFTthis function to view nft getFixedSaleNFT details 
     */
    function getFixedSaleNFT() external view returns (SaleInfo[] memory) {
        return fixedSaleNFT;
    }
     /*
        @notice its a view function to getNftAuctionSaleDetails
        @param getNftAuctionSaleDetails function to view nft getNftAuctionSaleDetails details 
     */
    function getNftAuctionSaleDetails(
        address _nftContractAddress,
        uint256 _tokenId
    ) external view returns (Auction memory) {
        return nftContractAuctionSale[_nftContractAddress][_tokenId];
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
