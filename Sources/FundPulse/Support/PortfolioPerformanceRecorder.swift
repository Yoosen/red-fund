import Foundation

enum PortfolioPerformanceRecorder {
    /// 待写入的一条每日收益记录候选：日期、收益、收益率、确认状态与更新时间。
    struct Candidate: Equatable, Sendable {
        var date: String
        var profit: Double
        var returnRate: Double
        var status: PortfolioPerformanceRecordStatus
        var updatedAt: Date
    }

    /// 判断行情确认状态：行情滞后的基金（如 QDII 净值 T+1 披露、估值时间非当日）不参与当日判定；
    /// 其余活跃持仓都有当日官方净值则返 `true`，均有当日估值则返 `false`；行情缺失或全部滞后则返 `nil`。
    static func quoteConfirmationState(
        portfolio: PortfolioSnapshot,
        quotes: [String: FundQuote],
        now: Date
    ) -> Bool? {
        let activeCodes = portfolio.funds
            .filter { ($0.isIncomeActive ?? false) && !$0.status.isPendingDisplay }
            .map(\.code)
        guard !activeCodes.isEmpty else { return nil }

        let today = DateOnlyFormatter.string(from: now)
        var allConfirmed = true
        var freshQuoteCount = 0
        for code in activeCodes {
            // 行情整体缺失时不记录，避免把不完整的组合收益写入日历。
            guard let quote = quotes[code] else { return nil }
            let isConfirmed = quote.netValueDate == today
            let isEstimated = quote.estimateTime.hasPrefix(today)
            // 行情滞后的基金（如 QDII 净值 T+1 披露）不参与当日判定，
            // 避免一只基金长期否决整个组合的收益记录。
            guard isConfirmed || isEstimated else { continue }
            freshQuoteCount += 1
            allConfirmed = allConfirmed && isConfirmed
        }
        // 全部基金行情都滞后（如非交易日）时不记录。
        guard freshQuoteCount > 0 else { return nil }
        return allConfirmed
    }

    /// 由当前组合快照生成一条待记录的收益候选：取今日收益与收益率，并按行情是否全部确认标记状态；组合为空或数值异常时返回 nil。
    static func candidate(
        from portfolio: PortfolioSnapshot,
        now: Date,
        allQuotesConfirmed: Bool
    ) -> Candidate? {
        guard !portfolio.funds.isEmpty,
              portfolio.todayIncome.isFinite,
              portfolio.todayIncomeRate.isFinite
        else {
            return nil
        }

        return Candidate(
            date: DateOnlyFormatter.string(from: now),
            profit: portfolio.todayIncome,
            returnRate: portfolio.todayIncomeRate,
            status: allQuotesConfirmed ? .confirmed : .estimated,
            updatedAt: now
        )
    }

    /// 把一条收益候选写入（或更新）收益快照：同日期则按替换规则覆盖，否则追加；并维护追踪起点与本地记录起点，最后排序归一化。
    static func recording(
        _ candidate: Candidate,
        in snapshot: PortfolioPerformanceSnapshot
    ) -> PortfolioPerformanceSnapshot {
        guard DateOnlyFormatter.parse(candidate.date) != nil,
              candidate.profit.isFinite,
              candidate.returnRate.isFinite
        else {
            return normalized(snapshot)
        }

        var next = normalized(snapshot)
        let day = PortfolioPerformanceDay(
            date: candidate.date,
            profit: candidate.profit,
            returnRate: candidate.returnRate,
            status: candidate.status,
            source: .localQuote,
            updatedAt: candidate.updatedAt
        )

        if let index = next.days.firstIndex(where: { $0.date == candidate.date }) {
            guard shouldReplace(existing: next.days[index], with: day) else {
                return next
            }
            next.days[index] = day
        } else {
            next.days.append(day)
        }

        next.days.sort { $0.date < $1.date }
        if let firstDate = next.days.first?.date {
            next.trackingStartDate = min(next.trackingStartDate ?? firstDate, firstDate)
        }
        next.localRecordingStartDate = min(
            next.localRecordingStartDate ?? candidate.date,
            candidate.date
        )
        return next
    }

    /// 归一化收益快照：剔除非法/非有限数值的日期，按日期去重并应用替换规则，重新排序，并修正追踪起点与本地记录起点。
    static func normalized(
        _ snapshot: PortfolioPerformanceSnapshot
    ) -> PortfolioPerformanceSnapshot {
        var selected: [String: PortfolioPerformanceDay] = [:]
        selected.reserveCapacity(snapshot.days.count)

        for day in snapshot.days where DateOnlyFormatter.parse(day.date) != nil
            && day.profit.isFinite
            && (day.returnRate?.isFinite ?? true)
        {
            if let existing = selected[day.date] {
                if shouldReplace(existing: existing, with: day) {
                    selected[day.date] = day
                }
            } else {
                selected[day.date] = day
            }
        }

        let days = selected.values.sorted { $0.date < $1.date }
        let firstDate = days.first?.date
        let validTrackingStart = snapshot.trackingStartDate.flatMap { value in
            DateOnlyFormatter.parse(value) == nil ? nil : value
        }
        let trackingStartDate: String?
        if let firstDate {
            trackingStartDate = min(validTrackingStart ?? firstDate, firstDate)
        } else {
            trackingStartDate = nil
        }

        let firstLocalDate = days.first(where: { $0.source == .localQuote })?.date
        let validLocalRecordingStart = snapshot.localRecordingStartDate.flatMap { value in
            DateOnlyFormatter.parse(value) == nil ? nil : value
        }
        let localRecordingStartDate: String?
        if let firstLocalDate {
            localRecordingStartDate = min(validLocalRecordingStart ?? firstLocalDate, firstLocalDate)
        } else {
            localRecordingStartDate = validLocalRecordingStart
        }

        return PortfolioPerformanceSnapshot(
            schemaVersion: PortfolioPerformanceSnapshot.currentSchemaVersion,
            trackingStartDate: trackingStartDate,
            localRecordingStartDate: localRecordingStartDate,
            days: days,
            jdFinanceSync: snapshot.jdFinanceSync
        )
    }

    /// 判断候选记录是否应覆盖已有记录：京东已确认记录优先于本地估值；已确认优先于估值；同状态则按更新时间较新者覆盖。
    private static func shouldReplace(
        existing: PortfolioPerformanceDay,
        with candidate: PortfolioPerformanceDay
    ) -> Bool {
        if existing.source == .jdFinance,
           existing.status == .confirmed,
           candidate.source == .localQuote {
            return false
        }
        if existing.status == .confirmed, candidate.status == .estimated {
            return false
        }
        if existing.status == .estimated, candidate.status == .confirmed {
            return true
        }
        if existing.status == candidate.status,
           existing.profit == candidate.profit,
           existing.returnRate == candidate.returnRate {
            return false
        }
        return candidate.updatedAt >= existing.updatedAt
    }
}

enum PortfolioPerformanceSeries {
    /// 生成累计收益曲线点：按日期顺序累加每日收益，得到每个时点的累计收益。
    static func cumulativePoints(
        in snapshot: PortfolioPerformanceSnapshot
    ) -> [PortfolioPerformancePoint] {
        let days = PortfolioPerformanceRecorder.normalized(snapshot).days
        var runningTotal = 0.0
        return days.map { day in
            runningTotal += day.profit
            return PortfolioPerformancePoint(day: day, cumulativeProfit: runningTotal)
        }
    }

    /// 生成某时间范围内（截至 endDate）的收益曲线点：先算累计曲线，再按范围截断到对应起点与终点。
    static func points(
        in snapshot: PortfolioPerformanceSnapshot,
        range: PortfolioPerformanceRange,
        through endDate: Date
    ) -> [PortfolioPerformancePoint] {
        let points = cumulativePoints(in: snapshot)
        guard let cutoff = cutoffDate(for: range, through: endDate) else {
            return points
        }
        let cutoffText = DateOnlyFormatter.string(from: cutoff)
        let endText = DateOnlyFormatter.string(from: endDate)
        return points.filter { $0.day.date >= cutoffText && $0.day.date <= endText }
    }

    /// 按时间范围（1 月/3 月/6 月/1 年/全部）计算曲线的起始截断日期；“全部”返回 nil。
    private static func cutoffDate(
        for range: PortfolioPerformanceRange,
        through endDate: Date
    ) -> Date? {
        let component: DateComponents
        switch range {
        case .oneMonth:
            component = DateComponents(month: -1)
        case .threeMonths:
            component = DateComponents(month: -3)
        case .sixMonths:
            component = DateComponents(month: -6)
        case .oneYear:
            component = DateComponents(year: -1)
        case .all:
            return nil
        }
        return PortfolioPerformanceCalendar.shanghaiCalendar.date(byAdding: component, to: endDate)
    }
}

enum PortfolioPerformanceCalendar {
    /// 返回以上海时区、周一为每周首日的公历日历，作为所有收益日期计算的基准。
    static var shanghaiCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    /// 生成某日期所在月份的日历网格：计算前置空白（按周一为首日）、日期单元格与后置空白，供收益日历展示。
    static func grid(monthContaining date: Date) -> PortfolioPerformanceMonthGrid {
        let calendar = shanghaiCalendar
        guard let monthStart = monthStart(containing: date),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return PortfolioPerformanceMonthGrid(monthKey: "", cells: [])
        }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        var cells = Array<String?>(repeating: nil, count: leadingBlanks)
        cells.reserveCapacity(42)

        for day in dayRange {
            guard let value = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else {
                continue
            }
            cells.append(DateOnlyFormatter.string(from: value))
        }

        let trailingBlanks = (7 - cells.count % 7) % 7
        cells.append(contentsOf: Array<String?>(repeating: nil, count: trailingBlanks))

        return PortfolioPerformanceMonthGrid(
            monthKey: String(DateOnlyFormatter.string(from: monthStart).prefix(7)),
            cells: cells
        )
    }

    /// 汇总某月的收益：统计该月每日盈亏总额、上涨/下跌天数、估值天数，供月份概览展示。
    /// 非交易日（周末与法定休市）的缓存记录不纳入统计。
    static func summary(
        in snapshot: PortfolioPerformanceSnapshot,
        monthContaining date: Date
    ) -> PortfolioPerformanceMonthSummary {
        let prefix = grid(monthContaining: date).monthKey + "-"
        let days = PortfolioPerformanceRecorder.normalized(snapshot).days.filter {
            $0.date.hasPrefix(prefix)
            // 排除非交易日的缓存记录（周末/节假日不应产生收益）。
            && DateOnlyFormatter.parse($0.date)
                .map(TradingCalendar.isFundTradingDay) ?? false
        }
        return PortfolioPerformanceMonthSummary(
            days: days,
            totalProfit: days.reduce(0) { $0 + $1.profit },
            riseDays: days.count { $0.profit > 0 },
            fallDays: days.count { $0.profit < 0 },
            estimatedDays: days.count { $0.status == .estimated }
        )
    }

    /// 把日期按月份偏移（正为后、负为前），用于日历翻月。
    static func shiftedMonth(from date: Date, by offset: Int) -> Date {
        let calendar = shanghaiCalendar
        return calendar.date(byAdding: .month, value: offset, to: date) ?? date
    }

    /// 把日期格式化为“yyyy年 M月”的月份标题文本。
    static func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = shanghaiCalendar
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = shanghaiCalendar.timeZone
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }

    /// 返回包含指定日期的当月第一天（置零时分秒），用于日历网格定位月初。
    static func monthStart(containing date: Date) -> Date? {
        let calendar = shanghaiCalendar
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components)
    }
}
