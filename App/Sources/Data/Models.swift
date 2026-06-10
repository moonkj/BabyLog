import Foundation

// MARK: - Enumerations

enum PregnancyStatus: String, Codable {
    case active
    case delivered
    case loss
    case paused
}

enum Gender: String, Codable {
    case girl
    case boy
    case unspecified
}

// MARK: - Pregnancy

struct Pregnancy: Identifiable, Codable, Equatable {
    let id: UUID
    var lmpDate: Date?
    var eddDate: Date?
    var fetusCount: Int
    var nickname: String?
    var clinic: String?
    var status: PregnancyStatus

    init(
        id: UUID = UUID(),
        lmpDate: Date? = nil,
        eddDate: Date? = nil,
        fetusCount: Int = 1,
        nickname: String? = nil,
        clinic: String? = nil,
        status: PregnancyStatus = .active
    ) {
        self.id = id
        self.lmpDate = lmpDate
        self.eddDate = eddDate
        self.fetusCount = fetusCount
        self.nickname = nickname
        self.clinic = clinic
        self.status = status
    }
}

// MARK: - Child

struct Child: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var birthDate: Date
    var gender: Gender?
    var profileImageRef: String?
    var caregiverRole: String?
    var pregnancyId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        gender: Gender? = nil,
        profileImageRef: String? = nil,
        caregiverRole: String? = nil,
        pregnancyId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.profileImageRef = profileImageRef
        self.caregiverRole = caregiverRole
        self.pregnancyId = pregnancyId
    }
}

// MARK: - GrowthRecord

struct GrowthRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var childId: UUID
    var date: Date
    var heightCm: Double?
    var weightKg: Double?
    var headCircumferenceCm: Double?

    init(
        id: UUID = UUID(),
        childId: UUID,
        date: Date,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        headCircumferenceCm: Double? = nil
    ) {
        self.id = id
        self.childId = childId
        self.date = date
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.headCircumferenceCm = headCircumferenceCm
    }
}

// MARK: - DiaryEntry

struct DiaryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var childId: UUID
    var date: Date
    var recordType: String
    var content: String?
    var milestone: String?
    /// 로컬 사진 파일명 (App Support/BabyLog/photos/). 서버 업로드 없음(CLAUDE.md 사진 비전송).
    var photoRef: String?

    init(
        id: UUID = UUID(),
        childId: UUID,
        date: Date,
        recordType: String,
        content: String? = nil,
        milestone: String? = nil,
        photoRef: String? = nil
    ) {
        self.id = id
        self.childId = childId
        self.date = date
        self.recordType = recordType
        self.content = content
        self.milestone = milestone
        self.photoRef = photoRef
    }
}

// MARK: - VaccineRecord

struct VaccineRecord: Identifiable, Codable, Equatable {
    let id: UUID
    var childId: UUID
    var vaccineId: String
    var scheduledDate: Date?
    var completedDate: Date?
    var hospital: String?

    init(
        id: UUID = UUID(),
        childId: UUID,
        vaccineId: String,
        scheduledDate: Date? = nil,
        completedDate: Date? = nil,
        hospital: String? = nil
    ) {
        self.id = id
        self.childId = childId
        self.vaccineId = vaccineId
        self.scheduledDate = scheduledDate
        self.completedDate = completedDate
        self.hospital = hospital
    }
}
