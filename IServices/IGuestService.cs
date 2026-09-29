using Models.Guest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices
{
    public interface IGuestService
    {
        Task<ApproveGuestResponse> ApproveGuestAsync(ApproveGuestRequest request);
        Task<PromoteAdminResponse> PromoteAdminAsync(PromoteAdminRequest request);
        Task<IEnumerable<ApprovedGuestResponse>> GetApprovedGuestsAsync(GetApprovedGuestsRequest request);
        Task<RemoveGuestResponse> RemoveGuestAsync(RemoveGuestRequest request);
        Task<DemoteAdminResponse> DemoteAdminAsync(DemoteAdminRequest request);
    }
}
