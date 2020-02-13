//
//  TxDetailViewController.swift
//  Cosmostation
//
//  Created by 정용주 on 2020/02/12.
//  Copyright © 2020 wannabit. All rights reserved.
//

import UIKit
import Alamofire
import SafariServices

class TxDetailViewController: BaseViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var txTableView: UITableView!
    @IBOutlet weak var dismissBtn: UIButton!
    @IBOutlet weak var controlLayer: UIStackView!
    @IBOutlet weak var errorLayer: CardView!
    @IBOutlet weak var errorMsg: UILabel!
    @IBOutlet weak var errorCode: UILabel!
    @IBOutlet weak var loadingLayer: UIView!
    @IBOutlet weak var loadingImg: LoadingImageView!
    @IBOutlet weak var loadingMsg: UILabel!
    
    var mIsGen: Bool = false
    var mTxHash: String?
    var mTxInfo: TxInfo?
    var mBroadCaseResult: [String:Any]?
    var mFetchCnt = 10
    var mAllValidator = Array<Validator>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.account = BaseData.instance.selectAccountById(id: BaseData.instance.getRecentAccountId())
        self.chainType = WUtils.getChainType(account!.account_base_chain)
        self.mAllValidator = BaseData.instance.getAllValidators()
        
        self.txTableView.delegate = self
        self.txTableView.dataSource = self
        self.txTableView.separatorStyle = UITableViewCell.SeparatorStyle.none
        self.txTableView.register(UINib(nibName: "TxCommonCell", bundle: nil), forCellReuseIdentifier: "TxCommonCell")
        self.txTableView.register(UINib(nibName: "TxCommissionCell", bundle: nil), forCellReuseIdentifier: "TxCommissionCell")
        self.txTableView.register(UINib(nibName: "TxDelegateCell", bundle: nil), forCellReuseIdentifier: "TxDelegateCell")
        self.txTableView.register(UINib(nibName: "TxUndelegateCell", bundle: nil), forCellReuseIdentifier: "TxUndelegateCell")
        self.txTableView.register(UINib(nibName: "TxRedelegateCell", bundle: nil), forCellReuseIdentifier: "TxRedelegateCell")
        self.txTableView.register(UINib(nibName: "TxTransferCell", bundle: nil), forCellReuseIdentifier: "TxTransferCell")
        self.txTableView.register(UINib(nibName: "TxMultiTransferCell", bundle: nil), forCellReuseIdentifier: "TxMultiTransferCell")
        self.txTableView.register(UINib(nibName: "TxRewardCell", bundle: nil), forCellReuseIdentifier: "TxRewardCell")
        self.txTableView.register(UINib(nibName: "TxEditRewardAddressCell", bundle: nil), forCellReuseIdentifier: "TxEditRewardAddressCell")
        self.txTableView.register(UINib(nibName: "TxVoteCell", bundle: nil), forCellReuseIdentifier: "TxVoteCell")
        self.txTableView.register(UINib(nibName: "TxUnknownCell", bundle: nil), forCellReuseIdentifier: "TxUnknownCell")
        self.txTableView.rowHeight = UITableView.automaticDimension
        self.txTableView.estimatedRowHeight = UITableView.automaticDimension
        
        if (mIsGen) {
            
        } else {
            self.loadingMsg.isHidden = true
            self.loadingImg.onStartAnimation()
            self.onFetchTx(mTxHash!)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.navigationController?.navigationBar.topItem?.title = NSLocalizedString("title_tx_detail", comment: "");
        self.navigationItem.title = NSLocalizedString("title_tx_detail", comment: "");
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (self.isMovingFromParent && mIsGen){
            self.onStartMainTab()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (mTxInfo != nil) {
            return (mTxInfo?.tx.value.msg.count)! + 1
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (indexPath.row == 0) {
            return onBindTxCommon(tableView)
        } else {
            let msg = mTxInfo?.tx.value.msg[indexPath.row - 1]
            if (msg?.type == COSMOS_MSG_TYPE_DELEGATE || msg?.type == IRIS_MSG_TYPE_DELEGATE) {
                return onBindDelegate(tableView, msg!)
                
            } else if (msg?.type == COSMOS_MSG_TYPE_UNDELEGATE || msg?.type == COSMOS_MSG_TYPE_UNDELEGATE2 || msg?.type == IRIS_MSG_TYPE_UNDELEGATE) {
                return onBindUndelegate(tableView, msg!)
                
            } else if (msg?.type == COSMOS_MSG_TYPE_REDELEGATE || msg?.type == COSMOS_MSG_TYPE_REDELEGATE2 || msg?.type == IRIS_MSG_TYPE_REDELEGATE) {
                return onBindRedelegate(tableView, msg!)
                
            } else if (msg?.type == COSMOS_MSG_TYPE_WITHDRAW_DEL || msg?.type == IRIS_MSG_TYPE_WITHDRAW) {
                return onBindGetReward(tableView, msg!)
                
            } else if (msg?.type == COSMOS_MSG_TYPE_WITHDRAW_MIDIFY || msg?.type == IRIS_MSG_TYPE_WITHDRAW_MIDIFY) {
                return onBindEditRewardAddress(tableView, msg!)
                
            } else if (msg?.type == COSMOS_MSG_TYPE_VOTE || msg?.type == IRIS_MSG_TYPE_VOTE) {
                return onBindVote(tableView, msg!)
                
            } else if (msg?.type == COSMOS_MSG_TYPE_WITHDRAW_VAL) {
                return onBindCommission(tableView, msg!)
                
            } else if (msg?.type == COSMOS_MSG_TYPE_TRANSFER || msg?.type == COSMOS_MSG_TYPE_TRANSFER2 || msg?.type == IRIS_MSG_TYPE_TRANSFER) {
                if ((msg?.value.inputs != nil && (msg?.value.inputs!.count)! > 1) ||  (msg?.value.outputs != nil && (msg?.value.outputs!.count)! > 1)) {
                    return onBindMultiTransfer(tableView, msg!)
                } else {
                    return onBindTransfer(tableView, msg!)
                }
            } else {
                let cell:TxUnknownCell? = tableView.dequeueReusableCell(withIdentifier:"TxUnknownCell") as? TxUnknownCell
                return cell!
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension;
    }
    
    func onBindTxCommon(_ tableView: UITableView) -> UITableViewCell {
        let cell:TxCommonCell? = tableView.dequeueReusableCell(withIdentifier:"TxCommonCell") as? TxCommonCell
        cell?.setDenomType(chainType!)
        if (chainType == ChainType.SUPPORT_CHAIN_COSMOS_MAIN || chainType == ChainType.SUPPORT_CHAIN_KAVA_MAIN) {
            cell?.feeLayer.isHidden = false
            cell?.usedFeeLayer.isHidden = true
            cell?.limitFeeLayer.isHidden = true
            if (mTxInfo!.isSuccess) {
                cell?.statusImg.image = UIImage(named: "successIc")
                cell?.statusLabel.text = NSLocalizedString("tx_success", comment: "")
            } else {
                cell?.statusImg.image = UIImage(named: "failIc")
                cell?.statusLabel.text = NSLocalizedString("tx_fail", comment: "")
            }
            cell?.heightLabel.text = mTxInfo!.height
            cell?.msgCntLabel.text = String(mTxInfo!.tx.value.msg.count)
            cell?.gasAmountLabel.text = mTxInfo!.gas_used + " / " + mTxInfo!.gas_wanted
            cell?.timeLabel.text = WUtils.txTimetoString(input: mTxInfo!.txTime)
            cell?.timeGapLabel.text = WUtils.txTimeGap(input: mTxInfo!.txTime)
            cell?.hashLabel.text = mTxInfo!.txhash
            cell?.memoLabel.text = mTxInfo!.tx.value.memo
            cell?.feeAmountLabel.attributedText = WUtils.displayAmount2((mTxInfo?.tx.value.fee.amount[0].amount)!, cell!.feeAmountLabel.font!, 6, 6)
            
        }
        return cell!
    }
    
    func onBindDelegate(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxDelegateCell? = tableView.dequeueReusableCell(withIdentifier:"TxDelegateCell") as? TxDelegateCell
        cell?.setDenomType(chainType!)
        cell?.txIcon.image = cell?.txIcon.image?.withRenderingMode(.alwaysTemplate)
        cell?.txIcon.tintColor = WUtils.getChainColor(chainType!)
        if (chainType == ChainType.SUPPORT_CHAIN_COSMOS_MAIN || chainType == ChainType.SUPPORT_CHAIN_KAVA_MAIN) {
            cell?.delegatorLabel.text = msg.value.delegator_address
            cell?.validatorLabel.text = msg.value.validator_address
            cell?.monikerLabel.text = WUtils.getMonikerName(mAllValidator, msg.value.validator_address!)
            cell?.delegateAmountLabel.attributedText = WUtils.displayAmount2((msg.value.getAmount()?.amount)!, cell!.delegateAmountLabel.font!, 6, 6)
            cell?.autoRewardAmountLabel.attributedText = WUtils.displayAmount2(mTxInfo?.getSimpleAutoReward(), cell!.delegateAmountLabel.font!, 6, 6)
            if (mTxInfo?.getMsgs().count == 1) {
                cell?.autoRewardLayer.isHidden = false
                cell?.autoRewardBottomConstraint.priority = .defaultHigh
                cell?.feeBottomConstraint.priority = .defaultLow
            } else {
                cell?.autoRewardLayer.isHidden = true
                cell?.autoRewardBottomConstraint.priority = .defaultLow
                cell?.feeBottomConstraint.priority = .defaultHigh
            }
        }
        return cell!
    }
    
    func onBindUndelegate(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxUndelegateCell? = tableView.dequeueReusableCell(withIdentifier:"TxUndelegateCell") as? TxUndelegateCell
        return cell!
    }
    
    func onBindRedelegate(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxRedelegateCell? = tableView.dequeueReusableCell(withIdentifier:"TxRedelegateCell") as? TxRedelegateCell
        return cell!
    }
    
    func onBindTransfer(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxTransferCell? = tableView.dequeueReusableCell(withIdentifier:"TxTransferCell") as? TxTransferCell
        return cell!
    }
    
    func onBindMultiTransfer(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxMultiTransferCell? = tableView.dequeueReusableCell(withIdentifier:"TxMultiTransferCell") as? TxMultiTransferCell
        return cell!
    }
    
    func onBindGetReward(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxRewardCell? = tableView.dequeueReusableCell(withIdentifier:"TxRewardCell") as? TxRewardCell
        return cell!
    }
    
    func onBindEditRewardAddress(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxEditRewardAddressCell? = tableView.dequeueReusableCell(withIdentifier:"TxEditRewardAddressCell") as? TxEditRewardAddressCell
        return cell!
    }
    
    func onBindVote(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxVoteCell? = tableView.dequeueReusableCell(withIdentifier:"TxVoteCell") as? TxVoteCell
        return cell!
    }
    
    func onBindCommission(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxCommissionCell? = tableView.dequeueReusableCell(withIdentifier:"TxCommissionCell") as? TxCommissionCell
        return cell!
    }
    
    func onBindUnknown(_ tableView: UITableView, _ msg: Msg) -> UITableViewCell  {
        let cell:TxUnknownCell? = tableView.dequeueReusableCell(withIdentifier:"TxUnknownCell") as? TxUnknownCell
        return cell!
    }
    
    
    
    @IBAction func onClickShare(_ sender: UIButton) {
    }
    
    @IBAction func onClickExplorer(_ sender: UIButton) {
    }
    
    @IBAction func onClickDismiss(_ sender: UIButton) {
    }
    
    
    
    
    
    
    func onShowMoreWait() {
        let noticeAlert = UIAlertController(title: NSLocalizedString("more_wait_title", comment: ""), message: NSLocalizedString("more_wait_msg", comment: ""), preferredStyle: .alert)
        noticeAlert.addAction(UIAlertAction(title: NSLocalizedString("close", comment: ""), style: .default, handler: { _ in
            self.dismiss(animated: true, completion: nil)
            self.onStartMainTab()
        }))
        noticeAlert.addAction(UIAlertAction(title: NSLocalizedString("wait", comment: ""), style: .default, handler: { _ in
            self.mFetchCnt = 10
            self.onFetchTx(self.mTxHash!)
        }))
        self.present(noticeAlert, animated: true) {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissAlertController))
            noticeAlert.view.superview?.subviews[0].addGestureRecognizer(tapGesture)
        }
    }
    
    
    func onFetchTx(_ txHash: String) {
        var url = ""
        var request:DataRequest?
        if (self.chainType! == ChainType.SUPPORT_CHAIN_COSMOS_MAIN) {
            url = CSS_LCD_URL_TX + txHash
            request = Alamofire.request(url, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:])
            
        } else if (self.chainType! == ChainType.SUPPORT_CHAIN_IRIS_MAIN) {
            url = IRIS_LCD_URL_TX + txHash
            request = Alamofire.request(url, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:])
            
        } else if (self.chainType! == ChainType.SUPPORT_CHAIN_BINANCE_MAIN) {
            url = BNB_URL_TX + txHash
            request = Alamofire.request(url, method: .get, parameters: ["format":"json"], encoding: URLEncoding.default, headers: [:])
            
        } else if (self.chainType! == ChainType.SUPPORT_CHAIN_KAVA_MAIN) {
            url = KAVA_TX + txHash
            request = Alamofire.request(url, method: .get, parameters: [:], encoding: URLEncoding.default, headers: [:])
            
        }
        request!.responseJSON { (response) in
            switch response.result {
            case .success(let res):
                if(SHOW_LOG) { print("onFetchTx OK", res) }
                guard let info = res as? [String : Any], info["error"] == nil else {
                    self.mFetchCnt = self.mFetchCnt - 1
                    if(self.mFetchCnt > 0) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(6000), execute: {
                            self.onFetchTx(txHash)
                        })
                    } else {
                        self.onShowMoreWait()
                    }
                    return
                }
                self.mTxInfo = TxInfo.init(info)
                
            case .failure(let error):
                if(SHOW_LOG) {
                    print("onFetchTx failure", error)
                }
                if (self.chainType! == ChainType.SUPPORT_CHAIN_IRIS_MAIN) {
                    self.mFetchCnt = self.mFetchCnt - 1
                    if(self.mFetchCnt > 0) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(6000), execute: {
                            self.onFetchTx(txHash)
                        })
                    } else {
                        self.onShowMoreWait()
                    }
                } else if (self.chainType! == ChainType.SUPPORT_CHAIN_BINANCE_MAIN) {
                    self.mFetchCnt = self.mFetchCnt - 1
                    if(self.mFetchCnt > 0) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1500), execute: {
                            self.onFetchTx(txHash)
                        })
                    } else {
                        self.onShowMoreWait()
                    }
                }
                return
            }
            self.loadingLayer.isHidden = true
            self.dismissBtn.isHidden = true
            self.controlLayer.isHidden = false
            self.txTableView.reloadData()
        }
        
    }
}