// Code generated by protoc-gen-gogo. DO NOT EDIT.
// source: envoy/data/tap/v3alpha/common.proto

package envoy_data_tap_v3alpha

import (
	fmt "fmt"
	proto "github.com/gogo/protobuf/proto"
	io "io"
	math "math"
	math_bits "math/bits"
)

// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf

// This is a compile-time assertion to ensure that this generated file
// is compatible with the proto package it is being compiled against.
// A compilation error at this line likely means your copy of the
// proto package needs to be updated.
const _ = proto.GoGoProtoPackageIsVersion2 // please upgrade the proto package

// Wrapper for tapped body data. This includes HTTP request/response body, transport socket received
// and transmitted data, etc.
type Body struct {
	// Types that are valid to be assigned to BodyType:
	//	*Body_AsBytes
	//	*Body_AsString
	BodyType isBody_BodyType `protobuf_oneof:"body_type"`
	// Specifies whether body data has been truncated to fit within the specified
	// :ref:`max_buffered_rx_bytes
	// <envoy_api_field_service.tap.v3alpha.OutputConfig.max_buffered_rx_bytes>` and
	// :ref:`max_buffered_tx_bytes
	// <envoy_api_field_service.tap.v3alpha.OutputConfig.max_buffered_tx_bytes>` settings.
	Truncated            bool     `protobuf:"varint,3,opt,name=truncated,proto3" json:"truncated,omitempty"`
	XXX_NoUnkeyedLiteral struct{} `json:"-"`
	XXX_unrecognized     []byte   `json:"-"`
	XXX_sizecache        int32    `json:"-"`
}

func (m *Body) Reset()         { *m = Body{} }
func (m *Body) String() string { return proto.CompactTextString(m) }
func (*Body) ProtoMessage()    {}
func (*Body) Descriptor() ([]byte, []int) {
	return fileDescriptor_901f3a8c29139e93, []int{0}
}
func (m *Body) XXX_Unmarshal(b []byte) error {
	return m.Unmarshal(b)
}
func (m *Body) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	if deterministic {
		return xxx_messageInfo_Body.Marshal(b, m, deterministic)
	} else {
		b = b[:cap(b)]
		n, err := m.MarshalToSizedBuffer(b)
		if err != nil {
			return nil, err
		}
		return b[:n], nil
	}
}
func (m *Body) XXX_Merge(src proto.Message) {
	xxx_messageInfo_Body.Merge(m, src)
}
func (m *Body) XXX_Size() int {
	return m.Size()
}
func (m *Body) XXX_DiscardUnknown() {
	xxx_messageInfo_Body.DiscardUnknown(m)
}

var xxx_messageInfo_Body proto.InternalMessageInfo

type isBody_BodyType interface {
	isBody_BodyType()
	MarshalTo([]byte) (int, error)
	Size() int
}

type Body_AsBytes struct {
	AsBytes []byte `protobuf:"bytes,1,opt,name=as_bytes,json=asBytes,proto3,oneof"`
}
type Body_AsString struct {
	AsString string `protobuf:"bytes,2,opt,name=as_string,json=asString,proto3,oneof"`
}

func (*Body_AsBytes) isBody_BodyType()  {}
func (*Body_AsString) isBody_BodyType() {}

func (m *Body) GetBodyType() isBody_BodyType {
	if m != nil {
		return m.BodyType
	}
	return nil
}

func (m *Body) GetAsBytes() []byte {
	if x, ok := m.GetBodyType().(*Body_AsBytes); ok {
		return x.AsBytes
	}
	return nil
}

func (m *Body) GetAsString() string {
	if x, ok := m.GetBodyType().(*Body_AsString); ok {
		return x.AsString
	}
	return ""
}

func (m *Body) GetTruncated() bool {
	if m != nil {
		return m.Truncated
	}
	return false
}

// XXX_OneofFuncs is for the internal use of the proto package.
func (*Body) XXX_OneofFuncs() (func(msg proto.Message, b *proto.Buffer) error, func(msg proto.Message, tag, wire int, b *proto.Buffer) (bool, error), func(msg proto.Message) (n int), []interface{}) {
	return _Body_OneofMarshaler, _Body_OneofUnmarshaler, _Body_OneofSizer, []interface{}{
		(*Body_AsBytes)(nil),
		(*Body_AsString)(nil),
	}
}

func _Body_OneofMarshaler(msg proto.Message, b *proto.Buffer) error {
	m := msg.(*Body)
	// body_type
	switch x := m.BodyType.(type) {
	case *Body_AsBytes:
		_ = b.EncodeVarint(1<<3 | proto.WireBytes)
		_ = b.EncodeRawBytes(x.AsBytes)
	case *Body_AsString:
		_ = b.EncodeVarint(2<<3 | proto.WireBytes)
		_ = b.EncodeStringBytes(x.AsString)
	case nil:
	default:
		return fmt.Errorf("Body.BodyType has unexpected type %T", x)
	}
	return nil
}

func _Body_OneofUnmarshaler(msg proto.Message, tag, wire int, b *proto.Buffer) (bool, error) {
	m := msg.(*Body)
	switch tag {
	case 1: // body_type.as_bytes
		if wire != proto.WireBytes {
			return true, proto.ErrInternalBadWireType
		}
		x, err := b.DecodeRawBytes(true)
		m.BodyType = &Body_AsBytes{x}
		return true, err
	case 2: // body_type.as_string
		if wire != proto.WireBytes {
			return true, proto.ErrInternalBadWireType
		}
		x, err := b.DecodeStringBytes()
		m.BodyType = &Body_AsString{x}
		return true, err
	default:
		return false, nil
	}
}

func _Body_OneofSizer(msg proto.Message) (n int) {
	m := msg.(*Body)
	// body_type
	switch x := m.BodyType.(type) {
	case *Body_AsBytes:
		n += 1 // tag and wire
		n += proto.SizeVarint(uint64(len(x.AsBytes)))
		n += len(x.AsBytes)
	case *Body_AsString:
		n += 1 // tag and wire
		n += proto.SizeVarint(uint64(len(x.AsString)))
		n += len(x.AsString)
	case nil:
	default:
		panic(fmt.Sprintf("proto: unexpected type %T in oneof", x))
	}
	return n
}

func init() {
	proto.RegisterType((*Body)(nil), "envoy.data.tap.v3alpha.Body")
}

func init() {
	proto.RegisterFile("envoy/data/tap/v3alpha/common.proto", fileDescriptor_901f3a8c29139e93)
}

var fileDescriptor_901f3a8c29139e93 = []byte{
	// 216 bytes of a gzipped FileDescriptorProto
	0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xff, 0x6c, 0x8f, 0x41, 0x4a, 0xc4, 0x30,
	0x14, 0x40, 0xe7, 0xab, 0x68, 0x9b, 0x71, 0xd5, 0x85, 0x14, 0xd4, 0x52, 0xd4, 0x45, 0x57, 0xc9,
	0x62, 0x4e, 0x60, 0xdc, 0xcc, 0x72, 0xa8, 0x07, 0x28, 0xbf, 0x93, 0xa0, 0x03, 0x36, 0x3f, 0x24,
	0xdf, 0xc1, 0xdc, 0xd0, 0xa5, 0x47, 0x90, 0x9e, 0x44, 0x1a, 0x04, 0x37, 0x6e, 0x1f, 0x6f, 0xf1,
	0x9e, 0xb8, 0xb7, 0xee, 0x48, 0x49, 0x19, 0x64, 0x54, 0x8c, 0x5e, 0x1d, 0x37, 0xf8, 0xe6, 0x5f,
	0x51, 0xed, 0x69, 0x9a, 0xc8, 0x49, 0x1f, 0x88, 0xa9, 0xba, 0xca, 0x92, 0x5c, 0x24, 0xc9, 0xe8,
	0xe5, 0xaf, 0x74, 0x37, 0x89, 0x33, 0x4d, 0x26, 0x55, 0xd7, 0xa2, 0xc0, 0x38, 0x8c, 0x89, 0x6d,
	0xac, 0xa1, 0x85, 0xee, 0x72, 0xbb, 0xea, 0x2f, 0x30, 0xea, 0x05, 0x54, 0xb7, 0xa2, 0xc4, 0x38,
	0x44, 0x0e, 0x07, 0xf7, 0x52, 0x9f, 0xb4, 0xd0, 0x95, 0xdb, 0x55, 0x5f, 0x60, 0x7c, 0xce, 0xa4,
	0xba, 0x11, 0x25, 0x87, 0x77, 0xb7, 0x47, 0xb6, 0xa6, 0x3e, 0x6d, 0xa1, 0x2b, 0xfa, 0x3f, 0xa0,
	0xd7, 0xa2, 0x1c, 0xc9, 0xa4, 0x81, 0x93, 0xb7, 0xfa, 0xf1, 0x73, 0x6e, 0xe0, 0x6b, 0x6e, 0xe0,
	0x7b, 0x6e, 0x40, 0x3c, 0x1c, 0x48, 0xe6, 0x2e, 0x1f, 0xe8, 0x23, 0xc9, 0xff, 0x13, 0xf5, 0xfa,
	0x29, 0x8f, 0xec, 0x96, 0x8f, 0x1d, 0x8c, 0xe7, 0x79, 0x68, 0xf3, 0x13, 0x00, 0x00, 0xff, 0xff,
	0x40, 0x2d, 0x80, 0xb8, 0xf7, 0x00, 0x00, 0x00,
}

func (m *Body) Marshal() (dAtA []byte, err error) {
	size := m.Size()
	dAtA = make([]byte, size)
	n, err := m.MarshalToSizedBuffer(dAtA[:size])
	if err != nil {
		return nil, err
	}
	return dAtA[:n], nil
}

func (m *Body) MarshalTo(dAtA []byte) (int, error) {
	size := m.Size()
	return m.MarshalToSizedBuffer(dAtA[:size])
}

func (m *Body) MarshalToSizedBuffer(dAtA []byte) (int, error) {
	i := len(dAtA)
	_ = i
	var l int
	_ = l
	if m.XXX_unrecognized != nil {
		i -= len(m.XXX_unrecognized)
		copy(dAtA[i:], m.XXX_unrecognized)
	}
	if m.Truncated {
		i--
		if m.Truncated {
			dAtA[i] = 1
		} else {
			dAtA[i] = 0
		}
		i--
		dAtA[i] = 0x18
	}
	if m.BodyType != nil {
		{
			size := m.BodyType.Size()
			i -= size
			if _, err := m.BodyType.MarshalTo(dAtA[i:]); err != nil {
				return 0, err
			}
		}
	}
	return len(dAtA) - i, nil
}

func (m *Body_AsBytes) MarshalTo(dAtA []byte) (int, error) {
	return m.MarshalToSizedBuffer(dAtA[:m.Size()])
}

func (m *Body_AsBytes) MarshalToSizedBuffer(dAtA []byte) (int, error) {
	i := len(dAtA)
	if m.AsBytes != nil {
		i -= len(m.AsBytes)
		copy(dAtA[i:], m.AsBytes)
		i = encodeVarintCommon(dAtA, i, uint64(len(m.AsBytes)))
		i--
		dAtA[i] = 0xa
	}
	return len(dAtA) - i, nil
}
func (m *Body_AsString) MarshalTo(dAtA []byte) (int, error) {
	return m.MarshalToSizedBuffer(dAtA[:m.Size()])
}

func (m *Body_AsString) MarshalToSizedBuffer(dAtA []byte) (int, error) {
	i := len(dAtA)
	i -= len(m.AsString)
	copy(dAtA[i:], m.AsString)
	i = encodeVarintCommon(dAtA, i, uint64(len(m.AsString)))
	i--
	dAtA[i] = 0x12
	return len(dAtA) - i, nil
}
func encodeVarintCommon(dAtA []byte, offset int, v uint64) int {
	offset -= sovCommon(v)
	base := offset
	for v >= 1<<7 {
		dAtA[offset] = uint8(v&0x7f | 0x80)
		v >>= 7
		offset++
	}
	dAtA[offset] = uint8(v)
	return base
}
func (m *Body) Size() (n int) {
	if m == nil {
		return 0
	}
	var l int
	_ = l
	if m.BodyType != nil {
		n += m.BodyType.Size()
	}
	if m.Truncated {
		n += 2
	}
	if m.XXX_unrecognized != nil {
		n += len(m.XXX_unrecognized)
	}
	return n
}

func (m *Body_AsBytes) Size() (n int) {
	if m == nil {
		return 0
	}
	var l int
	_ = l
	if m.AsBytes != nil {
		l = len(m.AsBytes)
		n += 1 + l + sovCommon(uint64(l))
	}
	return n
}
func (m *Body_AsString) Size() (n int) {
	if m == nil {
		return 0
	}
	var l int
	_ = l
	l = len(m.AsString)
	n += 1 + l + sovCommon(uint64(l))
	return n
}

func sovCommon(x uint64) (n int) {
	return (math_bits.Len64(x|1) + 6) / 7
}
func sozCommon(x uint64) (n int) {
	return sovCommon(uint64((x << 1) ^ uint64((int64(x) >> 63))))
}
func (m *Body) Unmarshal(dAtA []byte) error {
	l := len(dAtA)
	iNdEx := 0
	for iNdEx < l {
		preIndex := iNdEx
		var wire uint64
		for shift := uint(0); ; shift += 7 {
			if shift >= 64 {
				return ErrIntOverflowCommon
			}
			if iNdEx >= l {
				return io.ErrUnexpectedEOF
			}
			b := dAtA[iNdEx]
			iNdEx++
			wire |= uint64(b&0x7F) << shift
			if b < 0x80 {
				break
			}
		}
		fieldNum := int32(wire >> 3)
		wireType := int(wire & 0x7)
		if wireType == 4 {
			return fmt.Errorf("proto: Body: wiretype end group for non-group")
		}
		if fieldNum <= 0 {
			return fmt.Errorf("proto: Body: illegal tag %d (wire type %d)", fieldNum, wire)
		}
		switch fieldNum {
		case 1:
			if wireType != 2 {
				return fmt.Errorf("proto: wrong wireType = %d for field AsBytes", wireType)
			}
			var byteLen int
			for shift := uint(0); ; shift += 7 {
				if shift >= 64 {
					return ErrIntOverflowCommon
				}
				if iNdEx >= l {
					return io.ErrUnexpectedEOF
				}
				b := dAtA[iNdEx]
				iNdEx++
				byteLen |= int(b&0x7F) << shift
				if b < 0x80 {
					break
				}
			}
			if byteLen < 0 {
				return ErrInvalidLengthCommon
			}
			postIndex := iNdEx + byteLen
			if postIndex < 0 {
				return ErrInvalidLengthCommon
			}
			if postIndex > l {
				return io.ErrUnexpectedEOF
			}
			v := make([]byte, postIndex-iNdEx)
			copy(v, dAtA[iNdEx:postIndex])
			m.BodyType = &Body_AsBytes{v}
			iNdEx = postIndex
		case 2:
			if wireType != 2 {
				return fmt.Errorf("proto: wrong wireType = %d for field AsString", wireType)
			}
			var stringLen uint64
			for shift := uint(0); ; shift += 7 {
				if shift >= 64 {
					return ErrIntOverflowCommon
				}
				if iNdEx >= l {
					return io.ErrUnexpectedEOF
				}
				b := dAtA[iNdEx]
				iNdEx++
				stringLen |= uint64(b&0x7F) << shift
				if b < 0x80 {
					break
				}
			}
			intStringLen := int(stringLen)
			if intStringLen < 0 {
				return ErrInvalidLengthCommon
			}
			postIndex := iNdEx + intStringLen
			if postIndex < 0 {
				return ErrInvalidLengthCommon
			}
			if postIndex > l {
				return io.ErrUnexpectedEOF
			}
			m.BodyType = &Body_AsString{string(dAtA[iNdEx:postIndex])}
			iNdEx = postIndex
		case 3:
			if wireType != 0 {
				return fmt.Errorf("proto: wrong wireType = %d for field Truncated", wireType)
			}
			var v int
			for shift := uint(0); ; shift += 7 {
				if shift >= 64 {
					return ErrIntOverflowCommon
				}
				if iNdEx >= l {
					return io.ErrUnexpectedEOF
				}
				b := dAtA[iNdEx]
				iNdEx++
				v |= int(b&0x7F) << shift
				if b < 0x80 {
					break
				}
			}
			m.Truncated = bool(v != 0)
		default:
			iNdEx = preIndex
			skippy, err := skipCommon(dAtA[iNdEx:])
			if err != nil {
				return err
			}
			if skippy < 0 {
				return ErrInvalidLengthCommon
			}
			if (iNdEx + skippy) < 0 {
				return ErrInvalidLengthCommon
			}
			if (iNdEx + skippy) > l {
				return io.ErrUnexpectedEOF
			}
			m.XXX_unrecognized = append(m.XXX_unrecognized, dAtA[iNdEx:iNdEx+skippy]...)
			iNdEx += skippy
		}
	}

	if iNdEx > l {
		return io.ErrUnexpectedEOF
	}
	return nil
}
func skipCommon(dAtA []byte) (n int, err error) {
	l := len(dAtA)
	iNdEx := 0
	for iNdEx < l {
		var wire uint64
		for shift := uint(0); ; shift += 7 {
			if shift >= 64 {
				return 0, ErrIntOverflowCommon
			}
			if iNdEx >= l {
				return 0, io.ErrUnexpectedEOF
			}
			b := dAtA[iNdEx]
			iNdEx++
			wire |= (uint64(b) & 0x7F) << shift
			if b < 0x80 {
				break
			}
		}
		wireType := int(wire & 0x7)
		switch wireType {
		case 0:
			for shift := uint(0); ; shift += 7 {
				if shift >= 64 {
					return 0, ErrIntOverflowCommon
				}
				if iNdEx >= l {
					return 0, io.ErrUnexpectedEOF
				}
				iNdEx++
				if dAtA[iNdEx-1] < 0x80 {
					break
				}
			}
			return iNdEx, nil
		case 1:
			iNdEx += 8
			return iNdEx, nil
		case 2:
			var length int
			for shift := uint(0); ; shift += 7 {
				if shift >= 64 {
					return 0, ErrIntOverflowCommon
				}
				if iNdEx >= l {
					return 0, io.ErrUnexpectedEOF
				}
				b := dAtA[iNdEx]
				iNdEx++
				length |= (int(b) & 0x7F) << shift
				if b < 0x80 {
					break
				}
			}
			if length < 0 {
				return 0, ErrInvalidLengthCommon
			}
			iNdEx += length
			if iNdEx < 0 {
				return 0, ErrInvalidLengthCommon
			}
			return iNdEx, nil
		case 3:
			for {
				var innerWire uint64
				var start int = iNdEx
				for shift := uint(0); ; shift += 7 {
					if shift >= 64 {
						return 0, ErrIntOverflowCommon
					}
					if iNdEx >= l {
						return 0, io.ErrUnexpectedEOF
					}
					b := dAtA[iNdEx]
					iNdEx++
					innerWire |= (uint64(b) & 0x7F) << shift
					if b < 0x80 {
						break
					}
				}
				innerWireType := int(innerWire & 0x7)
				if innerWireType == 4 {
					break
				}
				next, err := skipCommon(dAtA[start:])
				if err != nil {
					return 0, err
				}
				iNdEx = start + next
				if iNdEx < 0 {
					return 0, ErrInvalidLengthCommon
				}
			}
			return iNdEx, nil
		case 4:
			return iNdEx, nil
		case 5:
			iNdEx += 4
			return iNdEx, nil
		default:
			return 0, fmt.Errorf("proto: illegal wireType %d", wireType)
		}
	}
	panic("unreachable")
}

var (
	ErrInvalidLengthCommon = fmt.Errorf("proto: negative length found during unmarshaling")
	ErrIntOverflowCommon   = fmt.Errorf("proto: integer overflow")
)
